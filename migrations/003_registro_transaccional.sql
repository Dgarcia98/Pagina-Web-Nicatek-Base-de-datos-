/* =====================================================================
   003 - REGISTRO TRANSACCIONAL DE VENTAS Y COMPRAS
   ---------------------------------------------------------------------
   PROBLEMA QUE RESUELVE
   El frontend creaba la cabecera y DESPUES insertaba los detalles uno por
   uno con Promise.allSettled. Si fallaban algunos quedaba:
       venta "Completado" + detalles parciales + stock parcialmente
       descontado + total de cabecera que no cuadra con los detalles
   y no habia compensacion: solo un toast de error.

   Ahora la venta entra completa o no entra. Un solo round-trip, una sola
   transaccion, y el precio lo pone la base de datos.

   Requiere haber corrido 002 primero (el trigger unificado).
   ===================================================================== */
USE NicaTek;
GO

SET NOCOUNT ON;
GO

/* =====================================================================
   PASO 1 - Tipos de tabla para recibir las lineas de un solo golpe
   ---------------------------------------------------------------------
   Los table types no admiten CREATE OR ALTER: hay que soltarlos y
   recrearlos. Como los usan los SPs, primero se sueltan los SPs.
   ===================================================================== */
IF OBJECT_ID('sp_Venta_Registrar', 'P')  IS NOT NULL DROP PROC sp_Venta_Registrar;
IF OBJECT_ID('sp_Compra_Registrar', 'P') IS NOT NULL DROP PROC sp_Compra_Registrar;
GO

IF TYPE_ID('dbo.TVP_Detalle_Venta') IS NOT NULL DROP TYPE dbo.TVP_Detalle_Venta;
GO
CREATE TYPE dbo.TVP_Detalle_Venta AS TABLE (
    Id_Producto INT NOT NULL,
    Id_Bodega   INT NULL,          -- NULL = elegir la bodega con mas stock
    Cantidad    INT NOT NULL
    -- El precio NO viene del cliente. Se lee de Tbl_Producto.
);
GO

IF TYPE_ID('dbo.TVP_Detalle_Compra') IS NOT NULL DROP TYPE dbo.TVP_Detalle_Compra;
GO
CREATE TYPE dbo.TVP_Detalle_Compra AS TABLE (
    Id_Producto            INT NOT NULL,
    Id_Bodega              INT NOT NULL,
    Cantidad               INT NOT NULL,
    Precio_Unitario_Compra DECIMAL(12,2) NOT NULL
    -- Aqui el precio SI viene del cliente: el costo se negocia con el
    -- proveedor y no existe en catalogo. El subtotal igual se recalcula.
);
GO
PRINT 'PASO 1: table types creados.';
GO

/* =====================================================================
   PASO 2 - sp_Venta_Registrar
   ---------------------------------------------------------------------
   Todo o nada. Valida, bloquea el stock, inserta cabecera + detalles +
   movimientos, y recalcula el total desde los precios reales.

   @O_Num  > 0  -> Id_Venta creada
   @O_Num  = -1 -> error de negocio, ver @O_Msg (mensaje apto para el
                   usuario final, sin detalles internos)
   ===================================================================== */
CREATE PROC sp_Venta_Registrar
    @Id_Cliente     INT,
    @Id_Metodo_Pago INT           = NULL,
    @Fecha          DATETIME      = NULL,
    @Id_Estado      INT           = 4,      -- 4 = Completado
    @Id_Usuario     INT,                    -- viene del token, no del body
    @Detalles       dbo.TVP_Detalle_Venta READONLY,
    @O_Num          INT           = NULL OUTPUT,
    @O_Msg          VARCHAR(255)  = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @O_Num = -1;

    ---------------------------------------------------------------------
    -- Validaciones que no necesitan transaccion
    ---------------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM @Detalles)
    BEGIN
        SET @O_Msg = 'La venta debe tener al menos un producto.';
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM @Detalles WHERE Cantidad <= 0)
    BEGIN
        SET @O_Msg = 'Todas las cantidades deben ser mayores a cero.';
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM Tbl_Cliente WHERE Id_Cliente = @Id_Cliente AND Id_Estado = 1)
    BEGIN
        SET @O_Msg = 'El cliente no existe o esta inactivo.';
        RETURN;
    END

    IF @Id_Metodo_Pago IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM Cls_Metodos_Pago WHERE Id_Metodo_Pago = @Id_Metodo_Pago)
    BEGIN
        SET @O_Msg = 'El metodo de pago seleccionado no existe.';
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM Tbl_Usuarios WHERE Id_Usuario = @Id_Usuario AND Id_Estado = 1)
    BEGIN
        SET @O_Msg = 'El usuario que registra la venta no existe o esta inactivo.';
        RETURN;
    END

    IF @Id_Estado NOT IN (4, 5)   -- Completado o Borrador
    BEGIN
        SET @O_Msg = 'Estado de venta invalido. Use Completado o Borrador.';
        RETURN;
    END

    ---------------------------------------------------------------------
    -- Consolidar lineas repetidas: el mismo producto en la misma bodega
    -- dos veces se suma. Si no, la validacion de stock se enganaria
    -- validando cada linea por separado contra el stock completo.
    ---------------------------------------------------------------------
    DECLARE @Lineas TABLE (
        Id_Producto        INT NOT NULL,
        Id_Bodega          INT NULL,
        Cantidad           INT NOT NULL,
        Precio             DECIMAL(12,2) NULL,
        Subtotal           DECIMAL(12,2) NULL,
        Id_Bodega_Producto INT NULL,
        Bodega_Resuelta    INT NULL,
        Stock_Disponible   INT NULL
    );

    INSERT INTO @Lineas (Id_Producto, Id_Bodega, Cantidad)
    SELECT Id_Producto, Id_Bodega, SUM(Cantidad)
    FROM @Detalles
    GROUP BY Id_Producto, Id_Bodega;

    ---------------------------------------------------------------------
    -- Precio de catalogo. Nunca del cliente.
    ---------------------------------------------------------------------
    UPDATE l
    SET l.Precio   = p.Precio,
        l.Subtotal = l.Cantidad * p.Precio
    FROM @Lineas l
    JOIN Tbl_Producto p ON p.Id_Producto = l.Id_Producto AND p.Id_Estado = 1;

    IF EXISTS (SELECT 1 FROM @Lineas WHERE Precio IS NULL)
    BEGIN
        SELECT TOP 1 @O_Msg = 'El producto con ID ' + CAST(Id_Producto AS VARCHAR)
                            + ' no existe o esta inactivo.'
        FROM @Lineas WHERE Precio IS NULL;
        RETURN;
    END

    DECLARE @Total DECIMAL(12,2) = (SELECT SUM(Subtotal) FROM @Lineas);

    BEGIN TRY
        BEGIN TRAN;

        -----------------------------------------------------------------
        -- Bloquear TODAS las filas de inventario de los productos de esta
        -- venta antes de validar. Sin esto, dos cajeros vendiendo la
        -- ultima unidad pasan ambos la validacion y uno deja el stock
        -- en negativo.
        -----------------------------------------------------------------
        DECLARE @Bloqueo INT;
        SELECT @Bloqueo = COUNT(*)
        FROM Tbl_Bodega_Producto WITH (UPDLOCK, HOLDLOCK)
        WHERE Id_Producto IN (SELECT Id_Producto FROM @Lineas);

        -----------------------------------------------------------------
        -- Resolver bodega: la pedida, o la que tenga mas stock
        -----------------------------------------------------------------
        UPDATE l
        SET l.Id_Bodega_Producto = bp.Id_Bodega_Producto,
            l.Bodega_Resuelta    = bp.Id_Bodega,
            l.Stock_Disponible   = bp.Cantidad
        FROM @Lineas l
        OUTER APPLY (
            SELECT TOP 1 x.Id_Bodega_Producto, x.Id_Bodega, x.Cantidad
            FROM Tbl_Bodega_Producto x
            WHERE x.Id_Producto = l.Id_Producto
              AND (l.Id_Bodega IS NULL OR x.Id_Bodega = l.Id_Bodega)
            ORDER BY x.Cantidad DESC
        ) bp;

        IF EXISTS (SELECT 1 FROM @Lineas WHERE Id_Bodega_Producto IS NULL)
        BEGIN
            SELECT TOP 1 @O_Msg = 'El producto "' + p.Nombre
                                + '" no tiene registro de inventario en bodega.'
            FROM @Lineas l JOIN Tbl_Producto p ON p.Id_Producto = l.Id_Producto
            WHERE l.Id_Bodega_Producto IS NULL;
            IF @@TRANCOUNT > 0 ROLLBACK;
            RETURN;
        END

        -----------------------------------------------------------------
        -- Validar stock de TODAS las lineas antes de tocar nada.
        -- (Los borradores no mueven inventario, por eso se saltan.)
        -----------------------------------------------------------------
        IF @Id_Estado = 4 AND EXISTS (SELECT 1 FROM @Lineas WHERE Stock_Disponible < Cantidad)
        BEGIN
            SELECT TOP 1 @O_Msg = 'Stock insuficiente de "' + p.Nombre
                                + '". Disponible: ' + CAST(l.Stock_Disponible AS VARCHAR)
                                + ', solicitado: '  + CAST(l.Cantidad AS VARCHAR) + '.'
            FROM @Lineas l JOIN Tbl_Producto p ON p.Id_Producto = l.Id_Producto
            WHERE l.Stock_Disponible < l.Cantidad
            ORDER BY p.Nombre;
            IF @@TRANCOUNT > 0 ROLLBACK;
            RETURN;
        END

        -----------------------------------------------------------------
        -- Empleado deducido del usuario autenticado
        -----------------------------------------------------------------
        DECLARE @Id_Empleado INT;
        SELECT @Id_Empleado = e.Id_Empleado
        FROM Tbl_Usuarios u
        JOIN Tbl_Datos_Personales dp ON dp.Id_Persona = u.Id_Persona
        JOIN Tbl_Empleado e          ON e.Id_Persona  = dp.Id_Persona
        WHERE u.Id_Usuario = @Id_Usuario;

        -----------------------------------------------------------------
        -- Cabecera
        -----------------------------------------------------------------
        INSERT INTO Tbl_Ventas (
            Fecha, Id_Cliente, Id_Empleado, Id_Metodo_Pago, Total,
            Id_Estado, Fecha_Creacion, Fecha_Modificacion, Id_Creador, Id_Modificador
        )
        VALUES (
            COALESCE(@Fecha, GETDATE()), @Id_Cliente, @Id_Empleado, @Id_Metodo_Pago,
            @Total, @Id_Estado, GETDATE(), GETDATE(), @Id_Usuario, @Id_Usuario
        );

        DECLARE @Id_Venta INT = SCOPE_IDENTITY();

        -----------------------------------------------------------------
        -- Detalles
        -----------------------------------------------------------------
        INSERT INTO Tbl_Detalle_Venta (
            Id_Venta, Id_Producto, Id_Bodega, Cantidad,
            Precio_Unitario_Al_Momento_Venta, Subtotal, Id_Estado,
            Fecha_Creacion, Fecha_Modificacion, Id_Creador, Id_Modificador
        )
        SELECT @Id_Venta, l.Id_Producto, l.Bodega_Resuelta, l.Cantidad,
               l.Precio, l.Subtotal, 1,
               GETDATE(), GETDATE(), @Id_Usuario, @Id_Usuario
        FROM @Lineas l;

        -----------------------------------------------------------------
        -- Movimientos de inventario. El trigger de 002 descuenta el stock
        -- y reescribe Stock_Anterior/Stock_Actual con los valores reales.
        -- Un borrador no mueve inventario.
        -----------------------------------------------------------------
        IF @Id_Estado = 4
        BEGIN
            INSERT INTO Tbl_Movimientos_Inventario (
                Id_Producto, Id_Bodega, Id_Bodega_Producto, Id_Tipo_Movimiento,
                Cantidad, Stock_Anterior, Stock_Actual, Costo_Unitario,
                Referencia, Observaciones, Fecha_Movimiento, Id_Usuario_Responsable
            )
            SELECT l.Id_Producto, l.Bodega_Resuelta, l.Id_Bodega_Producto, 2,
                   l.Cantidad, 0, 0, 0,
                   'Venta #' + CAST(@Id_Venta AS VARCHAR),
                   'Venta desde sistema', GETDATE(), @Id_Usuario
            FROM @Lineas l;
        END

        SET @O_Num = @Id_Venta;
        SET @O_Msg = 'Venta registrada correctamente.';
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @O_Num = -1;
        -- El mensaje del trigger de stock si es apto para el usuario.
        SET @O_Msg = CASE
            WHEN ERROR_MESSAGE() LIKE '%STOCK INSUFICIENTE%'
                THEN 'Stock insuficiente: otro usuario vendio estas unidades mientras registraba. Recargue e intente de nuevo.'
            ELSE 'No se pudo registrar la venta. ' + LEFT(ERROR_MESSAGE(), 200)
        END;
    END CATCH
END
GO
PRINT 'PASO 2: sp_Venta_Registrar creado.';
GO

/* =====================================================================
   PASO 3 - sp_Compra_Registrar
   ---------------------------------------------------------------------
   Mismo principio para compras. Diferencias:
     - El precio de compra SI lo aporta el cliente (es negociado)
     - Crea la fila de Tbl_Bodega_Producto si el producto es nuevo en
       esa bodega
     - La bodega es obligatoria por linea
   ===================================================================== */
CREATE PROC sp_Compra_Registrar
    @Id_Proveedor             INT,
    @Numero_Factura_Proveedor VARCHAR(50),
    @Fecha_Compra             DATE          = NULL,
    @Id_Estado                INT           = 4,
    @Id_Usuario               INT,
    @Detalles                 dbo.TVP_Detalle_Compra READONLY,
    @O_Num                    INT           = NULL OUTPUT,
    @O_Msg                    VARCHAR(255)  = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @O_Num = -1;

    IF NOT EXISTS (SELECT 1 FROM @Detalles)
    BEGIN
        SET @O_Msg = 'La compra debe tener al menos un producto.';
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM @Detalles WHERE Cantidad <= 0 OR Precio_Unitario_Compra < 0)
    BEGIN
        SET @O_Msg = 'Cantidades mayores a cero y precios no negativos.';
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM Tbl_Proveedor WHERE Id_Proveedor = @Id_Proveedor AND Id_Estado = 1)
    BEGIN
        SET @O_Msg = 'El proveedor no existe o esta inactivo.';
        RETURN;
    END

    IF ISNULL(LTRIM(RTRIM(@Numero_Factura_Proveedor)), '') = ''
    BEGIN
        SET @O_Msg = 'El numero de factura del proveedor es obligatorio.';
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM Tbl_Compra
               WHERE Id_Proveedor = @Id_Proveedor
                 AND Numero_Factura_Proveedor = @Numero_Factura_Proveedor)
    BEGIN
        SET @O_Msg = 'Ya existe una compra registrada con esa factura para este proveedor.';
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM Tbl_Usuarios WHERE Id_Usuario = @Id_Usuario AND Id_Estado = 1)
    BEGIN
        SET @O_Msg = 'El usuario que registra la compra no existe o esta inactivo.';
        RETURN;
    END

    DECLARE @Lineas TABLE (
        Id_Producto        INT NOT NULL,
        Id_Bodega          INT NOT NULL,
        Cantidad           INT NOT NULL,
        Precio             DECIMAL(12,2) NOT NULL,
        Subtotal           DECIMAL(12,2) NOT NULL,
        Id_Bodega_Producto INT NULL
    );

    -- Consolidar: mismo producto, misma bodega y mismo precio se suma.
    INSERT INTO @Lineas (Id_Producto, Id_Bodega, Cantidad, Precio, Subtotal)
    SELECT Id_Producto, Id_Bodega, SUM(Cantidad), Precio_Unitario_Compra,
           SUM(Cantidad) * Precio_Unitario_Compra
    FROM @Detalles
    GROUP BY Id_Producto, Id_Bodega, Precio_Unitario_Compra;

    IF EXISTS (SELECT 1 FROM @Lineas l
               WHERE NOT EXISTS (SELECT 1 FROM Tbl_Producto p
                                 WHERE p.Id_Producto = l.Id_Producto AND p.Id_Estado = 1))
    BEGIN
        SET @O_Msg = 'Uno de los productos no existe o esta inactivo.';
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM @Lineas l
               WHERE NOT EXISTS (SELECT 1 FROM Tbl_Bodega b
                                 WHERE b.Id_Bodega = l.Id_Bodega AND b.Id_Estado = 1))
    BEGIN
        SET @O_Msg = 'Una de las bodegas no existe o esta inactiva.';
        RETURN;
    END

    DECLARE @Id_Tipo_Movimiento INT;
    SELECT TOP 1 @Id_Tipo_Movimiento = Id_Tipo_Movimiento
    FROM Cls_Tipo_Movimiento
    WHERE Descripcion = 'Compra a Proveedor' AND Operacion IN ('SUMA','Entrada');

    IF @Id_Tipo_Movimiento IS NULL
    BEGIN
        SET @O_Msg = 'Falta el tipo de movimiento "Compra a Proveedor" en el catalogo.';
        RETURN;
    END

    DECLARE @Total DECIMAL(12,2) = (SELECT SUM(Subtotal) FROM @Lineas);

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @Bloqueo INT;
        SELECT @Bloqueo = COUNT(*)
        FROM Tbl_Bodega_Producto WITH (UPDLOCK, HOLDLOCK)
        WHERE Id_Producto IN (SELECT Id_Producto FROM @Lineas);

        -- Crear las combinaciones bodega-producto que aun no existan
        INSERT INTO Tbl_Bodega_Producto (
            Id_Bodega, Id_Producto, Cantidad,
            Fecha_Creacion, Fecha_Modificacion, Id_Creador, Id_Modificador
        )
        SELECT DISTINCT l.Id_Bodega, l.Id_Producto, 0,
               GETDATE(), GETDATE(), @Id_Usuario, @Id_Usuario
        FROM @Lineas l
        WHERE NOT EXISTS (
            SELECT 1 FROM Tbl_Bodega_Producto bp
            WHERE bp.Id_Bodega = l.Id_Bodega AND bp.Id_Producto = l.Id_Producto
        );

        UPDATE l
        SET l.Id_Bodega_Producto = bp.Id_Bodega_Producto
        FROM @Lineas l
        JOIN Tbl_Bodega_Producto bp
              ON bp.Id_Bodega = l.Id_Bodega AND bp.Id_Producto = l.Id_Producto;

        INSERT INTO Tbl_Compra (
            Id_Proveedor, Numero_Factura_Proveedor, Fecha_Compra, Total_Compra,
            Id_Estado, Fecha_Creacion, Fecha_Modificacion, Id_Creador, Id_Modificador
        )
        VALUES (
            @Id_Proveedor, @Numero_Factura_Proveedor, COALESCE(@Fecha_Compra, GETDATE()),
            @Total, @Id_Estado, GETDATE(), GETDATE(), @Id_Usuario, @Id_Usuario
        );

        DECLARE @Id_Compra INT = SCOPE_IDENTITY();

        INSERT INTO Tbl_Detalle_Compra (
            Id_Compra, Id_Producto, Id_Bodega, Cantidad,
            Precio_Unitario_Compra, Subtotal_Compra,
            Fecha_Creacion, Fecha_Modificacion, Id_Creador, Id_Modificador
        )
        SELECT @Id_Compra, l.Id_Producto, l.Id_Bodega, l.Cantidad,
               l.Precio, l.Subtotal, GETDATE(), GETDATE(), @Id_Usuario, @Id_Usuario
        FROM @Lineas l;

        INSERT INTO Tbl_Movimientos_Inventario (
            Id_Producto, Id_Bodega, Id_Bodega_Producto, Id_Tipo_Movimiento,
            Cantidad, Stock_Anterior, Stock_Actual, Costo_Unitario,
            Referencia, Observaciones, Fecha_Movimiento, Id_Usuario_Responsable
        )
        SELECT l.Id_Producto, l.Id_Bodega, l.Id_Bodega_Producto, @Id_Tipo_Movimiento,
               l.Cantidad, 0, 0, l.Precio,
               'Compra #' + CAST(@Id_Compra AS VARCHAR),
               'Entrada por compra', GETDATE(), @Id_Usuario
        FROM @Lineas l;

        SET @O_Num = @Id_Compra;
        SET @O_Msg = 'Compra registrada correctamente.';
        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        SET @O_Num = -1;
        SET @O_Msg = 'No se pudo registrar la compra. ' + LEFT(ERROR_MESSAGE(), 200);
    END CATCH
END
GO
PRINT 'PASO 3: sp_Compra_Registrar creado.';
GO

/* =====================================================================
   PASO 4 - sp_Dashboard_Resumen
   ---------------------------------------------------------------------
   Reemplaza al dashboard que se descargaba TODAS las ventas, TODAS las
   compras y TODOS los detalles para sumarlos en el navegador.
   Devuelve 5 result sets chicos ya agregados.
   ===================================================================== */
CREATE OR ALTER PROC sp_Dashboard_Resumen
    @Desde DATETIME = NULL,
    @Hasta DATETIME = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @Desde = COALESCE(@Desde, DATEADD(MONTH, -6, GETDATE()));
    SET @Hasta = COALESCE(@Hasta, GETDATE());

    -- 1. Totales del periodo
    SELECT
        (SELECT ISNULL(SUM(Total),0) FROM Tbl_Ventas
          WHERE Id_Estado <> 3 AND Fecha BETWEEN @Desde AND @Hasta)          AS Total_Ventas,
        (SELECT ISNULL(SUM(Total_Compra),0) FROM Tbl_Compra
          WHERE Id_Estado <> 3 AND Fecha_Compra BETWEEN @Desde AND @Hasta)   AS Total_Compras,
        (SELECT COUNT(*) FROM Tbl_Ventas
          WHERE Id_Estado <> 3 AND Fecha BETWEEN @Desde AND @Hasta)          AS Cantidad_Ventas,
        (SELECT COUNT(*) FROM Tbl_Compra
          WHERE Id_Estado <> 3 AND Fecha_Compra BETWEEN @Desde AND @Hasta)   AS Cantidad_Compras,
        (SELECT COUNT(*) FROM Tbl_Ventas WHERE Id_Estado = 3)                AS Ventas_Anuladas,
        (SELECT COUNT(*) FROM Tbl_Compra WHERE Id_Estado = 3)                AS Compras_Anuladas,
        (SELECT COUNT(*) FROM Tbl_Ventas)                                    AS Ventas_Totales_Historico,
        (SELECT COUNT(*) FROM Tbl_Compra)                                    AS Compras_Totales_Historico;

    -- 2. Serie de 6 meses
    ;WITH Meses AS (
        SELECT 0 AS N UNION ALL SELECT 1 UNION ALL SELECT 2
        UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5
    )
    SELECT
        YEAR(DATEADD(MONTH, -m.N, GETDATE()))  AS Anio,
        MONTH(DATEADD(MONTH, -m.N, GETDATE())) AS Mes,
        (SELECT ISNULL(SUM(v.Total),0) FROM Tbl_Ventas v
          WHERE v.Id_Estado <> 3
            AND YEAR(v.Fecha)  = YEAR(DATEADD(MONTH, -m.N, GETDATE()))
            AND MONTH(v.Fecha) = MONTH(DATEADD(MONTH, -m.N, GETDATE()))) AS Ventas,
        (SELECT ISNULL(SUM(c.Total_Compra),0) FROM Tbl_Compra c
          WHERE c.Id_Estado <> 3
            AND YEAR(c.Fecha_Compra)  = YEAR(DATEADD(MONTH, -m.N, GETDATE()))
            AND MONTH(c.Fecha_Compra) = MONTH(DATEADD(MONTH, -m.N, GETDATE()))) AS Compras
    FROM Meses m
    ORDER BY Anio, Mes;

    -- 3. Top 7 productos por unidades vendidas
    SELECT TOP 7
        p.Nombre AS Producto,
        SUM(dv.Cantidad) AS Unidades,
        SUM(dv.Subtotal) AS Monto
    FROM Tbl_Detalle_Venta dv
    JOIN Tbl_Producto p ON p.Id_Producto = dv.Id_Producto
    JOIN Tbl_Ventas   v ON v.Id_Venta    = dv.Id_Venta
    WHERE dv.Id_Estado <> 3 AND v.Id_Estado <> 3
      AND v.Fecha BETWEEN @Desde AND @Hasta
    GROUP BY p.Nombre
    ORDER BY SUM(dv.Cantidad) DESC;

    -- 4. Ultimas 5 ventas
    SELECT TOP 5
        v.Id_Venta, v.Numero_Factura, v.Fecha, v.Total,
        LTRIM(RTRIM(ISNULL(dp.Primer_Nombre,'') + ' ' + ISNULL(dp.Primer_Apellido,''))) AS Cliente
    FROM Tbl_Ventas v
    JOIN Tbl_Cliente c           ON c.Id_Cliente = v.Id_Cliente
    JOIN Tbl_Datos_Personales dp ON dp.Id_Persona = c.Id_Persona
    WHERE v.Id_Estado <> 3
    ORDER BY v.Id_Venta DESC;

    -- 5. Ultimas 5 compras
    SELECT TOP 5
        c.Id_Compra, c.Numero_Factura_Proveedor, c.Fecha_Compra, c.Total_Compra,
        LTRIM(RTRIM(ISNULL(dp.Primer_Nombre,'') + ' ' + ISNULL(dp.Primer_Apellido,''))) AS Proveedor
    FROM Tbl_Compra c
    JOIN Tbl_Proveedor pr        ON pr.Id_Proveedor = c.Id_Proveedor
    JOIN Tbl_Datos_Personales dp ON dp.Id_Persona   = pr.Id_Persona
    WHERE c.Id_Estado <> 3
    ORDER BY c.Id_Compra DESC;
END
GO
PRINT 'PASO 4: sp_Dashboard_Resumen creado.';
GO

/* =====================================================================
   PASO 5 - sp_Usuario_Permisos
   ---------------------------------------------------------------------
   La API necesita los permisos del usuario para meterlos como claims en
   el token, en vez de confiar en el sessionStorage del navegador.
   ===================================================================== */
CREATE OR ALTER PROC sp_Usuario_Permisos
    @Id_Usuario INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DISTINCT pe.Codigo_Permiso
    FROM Tbl_Usuarios u
    JOIN Tbl_Roles_Permisos rp ON rp.Id_Rol = u.Id_Rol AND rp.Activo = 1
    JOIN Cls_Permisos pe       ON pe.Id_Permiso = rp.Id_Permiso
    WHERE u.Id_Usuario = @Id_Usuario
      AND u.Id_Estado  = 1
      AND ISNULL(pe.Id_Estado, 1) = 1;
END
GO
PRINT 'PASO 5: sp_Usuario_Permisos creado.';
GO

PRINT '';
PRINT '=====================================================================';
PRINT ' 003 COMPLETADO';
PRINT '=====================================================================';
GO
