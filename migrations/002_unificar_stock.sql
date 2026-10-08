/* =====================================================================
   002 - UNIFICAR EL MECANISMO DE STOCK
   ---------------------------------------------------------------------
   PROBLEMA QUE RESUELVE
   Habia tres formas distintas de mover inventario conviviendo:
     a) sp_Tbl_Detalle_Compra : solo movimiento  -> el trigger actualiza
     b) sp_Tbl_Detalle_Venta  : UPDATE manual + movimiento SIN vinculo
     c) sp_Tbl_Ventas   (DEL) : UPDATE manual + movimiento SIN vinculo
        sp_Tbl_Compra   (DEL) : solo movimiento SIN vinculo -> NO descuenta

   Como los movimientos de (b) y (c) no traian Id_Bodega_Producto, el
   trigger no los emparejaba y no duplicaba. Funcionaba de casualidad.
   El caso (d) directamente perdia el descuento: anular una compra dejaba
   el stock inflado.

   REGLA UNICA A PARTIR DE AQUI
     El UNICO que escribe Tbl_Bodega_Producto.Cantidad es el trigger.
     Ningun SP vuelve a hacer UPDATE de Cantidad a mano.
     Todo movimiento DEBE traer Id_Bodega_Producto (el trigger lo exige).

   ORDEN: correr 000 (auditoria) primero, luego 001, luego este.
   ===================================================================== */
USE NicaTek;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* =====================================================================
   PASO 1 - Retirar el guardian muerto
   ---------------------------------------------------------------------
   tr_EvitarStockNegativo vigilaba Tbl_Bodega, pero el stock se mudo a
   Tbl_Bodega_Producto en la migracion multi-bodega. Llevaba tiempo sin
   proteger nada. Su reemplazo va dentro del trigger de kardex (paso 2)
   mas un CHECK a nivel de tabla (paso 3).
   ===================================================================== */
IF OBJECT_ID('tr_EvitarStockNegativo', 'TR') IS NOT NULL
BEGIN
    DROP TRIGGER tr_EvitarStockNegativo;
    PRINT 'PASO 1: tr_EvitarStockNegativo eliminado (vigilaba una tabla obsoleta).';
END
ELSE
    PRINT 'PASO 1: tr_EvitarStockNegativo no existe. Nada que hacer.';
GO

/* =====================================================================
   PASO 2 - Trigger de kardex: fuente unica de verdad
   ---------------------------------------------------------------------
   Ademas de mover el stock ahora:
     - RECHAZA movimientos sin Id_Bodega_Producto (antes se perdian en
       silencio, que es exactamente como se descuadro el inventario)
     - REESCRIBE Stock_Anterior / Stock_Actual con los valores reales,
       para que el kardex no dependa de lo que calculo el SP llamador
     - BLOQUEA stock negativo
     - Es set-based: soporta insercion de varias filas de un golpe
     - Acepta 'SUMA'/'RESTA' y 'Entrada'/'Salida' porque el esquema
       original documentaba unos valores y los triggers usaban otros
   ===================================================================== */
CREATE OR ALTER TRIGGER tr_ActualizarStock_Desde_Kardex
ON Tbl_Movimientos_Inventario
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;

    ---------------------------------------------------------------------
    -- 2.a Ningun movimiento puede quedar sin vincular a bodega-producto.
    --     Si esto salta, el SP llamador esta mal: corregirlo, no quitar
    --     la validacion.
    ---------------------------------------------------------------------
    IF EXISTS (SELECT 1 FROM inserted WHERE Id_Bodega_Producto IS NULL)
    BEGIN
        RAISERROR ('Movimiento de inventario sin Id_Bodega_Producto: el stock no se actualizaria y el kardex quedaria descuadrado. Corrija el procedimiento que inserto el movimiento.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    ---------------------------------------------------------------------
    -- 2.b Tipo de movimiento valido
    ---------------------------------------------------------------------
    IF EXISTS (
        SELECT 1
        FROM inserted i
        LEFT JOIN Cls_Tipo_Movimiento tm ON tm.Id_Tipo_Movimiento = i.Id_Tipo_Movimiento
        WHERE tm.Id_Tipo_Movimiento IS NULL
           OR tm.Operacion NOT IN ('SUMA', 'RESTA', 'Entrada', 'Salida')
    )
    BEGIN
        RAISERROR ('Tipo de movimiento inexistente o con Operacion invalida (se espera SUMA/RESTA o Entrada/Salida).', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    ---------------------------------------------------------------------
    -- 2.c Aplicar el delta neto sobre el stock
    ---------------------------------------------------------------------
    ;WITH Deltas AS (
        SELECT  i.Id_Bodega_Producto,
                SUM(CASE WHEN tm.Operacion IN ('SUMA','Entrada')  THEN  i.Cantidad
                         WHEN tm.Operacion IN ('RESTA','Salida')  THEN -i.Cantidad
                         ELSE 0 END) AS Delta
        FROM inserted i
        JOIN Cls_Tipo_Movimiento tm ON tm.Id_Tipo_Movimiento = i.Id_Tipo_Movimiento
        GROUP BY i.Id_Bodega_Producto
    )
    UPDATE bp
    SET bp.Cantidad           = bp.Cantidad + d.Delta,
        bp.Fecha_Modificacion = GETDATE()
    FROM Tbl_Bodega_Producto bp
    JOIN Deltas d ON d.Id_Bodega_Producto = bp.Id_Bodega_Producto;

    ---------------------------------------------------------------------
    -- 2.d Reescribir el kardex con los valores REALES post-movimiento.
    --     Asi Stock_Anterior/Stock_Actual nunca mienten, sin importar lo
    --     que haya calculado quien inserto.
    ---------------------------------------------------------------------
    UPDATE m
    SET m.Stock_Actual   = bp.Cantidad,
        m.Stock_Anterior = bp.Cantidad - (CASE WHEN tm.Operacion IN ('SUMA','Entrada')  THEN  m.Cantidad
                                               WHEN tm.Operacion IN ('RESTA','Salida')  THEN -m.Cantidad
                                               ELSE 0 END)
    FROM Tbl_Movimientos_Inventario m
    JOIN inserted i               ON i.Id_Movimiento      = m.Id_Movimiento
    JOIN Tbl_Bodega_Producto bp   ON bp.Id_Bodega_Producto = m.Id_Bodega_Producto
    JOIN Cls_Tipo_Movimiento tm   ON tm.Id_Tipo_Movimiento = m.Id_Tipo_Movimiento;

    ---------------------------------------------------------------------
    -- 2.e Stock negativo: reemplaza al viejo tr_EvitarStockNegativo
    ---------------------------------------------------------------------
    IF EXISTS (
        SELECT 1
        FROM Tbl_Bodega_Producto bp
        JOIN inserted i ON i.Id_Bodega_Producto = bp.Id_Bodega_Producto
        WHERE bp.Cantidad < 0
    )
    BEGIN
        RAISERROR ('STOCK INSUFICIENTE: la operacion dejaria el inventario en negativo.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END
GO
PRINT 'PASO 2: tr_ActualizarStock_Desde_Kardex recreado como fuente unica de verdad.';
GO

/* =====================================================================
   PASO 3 - Red de seguridad a nivel de tabla
   ---------------------------------------------------------------------
   Aunque alguien haga un UPDATE manual desde SSMS, el stock no puede
   quedar negativo. Solo se crea si no hay datos negativos ya guardados.
   ===================================================================== */
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_Bodega_Producto_Cantidad_No_Negativa')
BEGIN
    IF EXISTS (SELECT 1 FROM Tbl_Bodega_Producto WHERE Cantidad < 0)
        PRINT 'PASO 3: OMITIDO. Hay filas con Cantidad < 0. Corrija esos datos (ver consulta 4 de 000_auditoria_stock.sql) y vuelva a correr este bloque.';
    ELSE
    BEGIN
        ALTER TABLE Tbl_Bodega_Producto
            ADD CONSTRAINT CK_Bodega_Producto_Cantidad_No_Negativa CHECK (Cantidad >= 0);
        PRINT 'PASO 3: CHECK de cantidad no negativa agregado.';
    END
END
ELSE
    PRINT 'PASO 3: el CHECK ya existia.';
GO

/* =====================================================================
   PASO 4 - sp_Tbl_Detalle_Venta
   ---------------------------------------------------------------------
   Cambios:
     - Ya NO hace UPDATE manual del stock (lo hace el trigger)
     - Envia Id_Bodega_Producto en el movimiento
     - Lee el stock con UPDLOCK/HOLDLOCK DENTRO de la transaccion, para
       cerrar la condicion de carrera: dos cajeros vendiendo la ultima
       unidad al mismo tiempo ya no pasan ambos la validacion
     - El precio unitario ahora es OBLIGATORIO y se valida contra el
       producto; el subtotal se recalcula siempre en el servidor
   ===================================================================== */
CREATE OR ALTER PROC sp_Tbl_Detalle_Venta
    @Mode                             VARCHAR(3)    = NULL,
    @O_Msg                            VARCHAR(255)  = NULL OUTPUT,
    @O_Num                            INT           = NULL OUTPUT,
    @Id_Detalle                       INT           = NULL,
    @Id_Venta                         INT           = NULL,
    @Id_Producto                      INT           = NULL,
    @Id_Bodega                        INT           = NULL,
    @Cantidad                         INT           = NULL,
    @Precio_Unitario_Al_Momento_Venta DECIMAL(12,2) = NULL,
    @Subtotal                         DECIMAL(12,2) = NULL,
    @Id_Estado                        INT           = NULL,
    @Id_Creador                       INT           = NULL,
    @Id_Modificador                   INT           = NULL,
    @Filtro                           VARCHAR(100)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Id_Modificador IS NULL SET @Id_Modificador = @Id_Creador;

    IF @Mode = 'INS'
    BEGIN
        IF @Id_Venta IS NULL OR @Id_Producto IS NULL OR @Cantidad IS NULL OR @Id_Creador IS NULL
        BEGIN
            SET @O_Msg = 'Faltan campos obligatorios en el Detalle.';
            SET @O_Num = -1; RETURN;
        END

        IF @Cantidad <= 0
        BEGIN
            SET @O_Msg = 'La cantidad debe ser mayor a cero.';
            SET @O_Num = -1; RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Tbl_Ventas WHERE Id_Venta = @Id_Venta)
        BEGIN
            SET @O_Msg = 'La venta especificada no existe.';
            SET @O_Num = -1; RETURN;
        END

        -- El precio SIEMPRE sale de la base, nunca del cliente.
        DECLARE @PrecioReal DECIMAL(12,2);
        SELECT @PrecioReal = Precio FROM Tbl_Producto
        WHERE Id_Producto = @Id_Producto AND Id_Estado = 1;

        IF @PrecioReal IS NULL
        BEGIN
            SET @O_Msg = 'El producto no existe o esta inactivo.';
            SET @O_Num = -1; RETURN;
        END

        SET @Precio_Unitario_Al_Momento_Venta = @PrecioReal;
        SET @Subtotal = @Cantidad * @PrecioReal;

        DECLARE @Id_Bodega_Producto INT, @StockAnterior INT;

        BEGIN TRY
            BEGIN TRAN;

            -- Bloqueo dentro de la transaccion: nadie mas lee este stock
            -- hasta que terminemos. Cierra la carrera entre dos cajeros.
            IF @Id_Bodega IS NOT NULL
            BEGIN
                SELECT @Id_Bodega_Producto = Id_Bodega_Producto,
                       @StockAnterior      = Cantidad,
                       @Id_Bodega          = Id_Bodega
                FROM Tbl_Bodega_Producto WITH (UPDLOCK, HOLDLOCK)
                WHERE Id_Bodega = @Id_Bodega AND Id_Producto = @Id_Producto;
            END
            ELSE
            BEGIN
                -- Sin bodega explicita: la que tenga mas stock disponible.
                SELECT TOP 1
                       @Id_Bodega_Producto = Id_Bodega_Producto,
                       @StockAnterior      = Cantidad,
                       @Id_Bodega          = Id_Bodega
                FROM Tbl_Bodega_Producto WITH (UPDLOCK, HOLDLOCK)
                WHERE Id_Producto = @Id_Producto
                ORDER BY Cantidad DESC;
            END

            IF @Id_Bodega_Producto IS NULL
            BEGIN
                IF @@TRANCOUNT > 0 ROLLBACK;
                SET @O_Msg = 'El producto no tiene registro de inventario en bodega.';
                SET @O_Num = -1; RETURN;
            END

            IF @StockAnterior < @Cantidad
            BEGIN
                IF @@TRANCOUNT > 0 ROLLBACK;
                SET @O_Msg = 'Stock insuficiente. Disponible: ' + CAST(@StockAnterior AS VARCHAR);
                SET @O_Num = -1; RETURN;
            END

            INSERT INTO Tbl_Detalle_Venta (
                Id_Venta, Id_Producto, Id_Bodega, Cantidad,
                Precio_Unitario_Al_Momento_Venta, Subtotal, Id_Estado,
                Fecha_Creacion, Fecha_Modificacion, Id_Creador, Id_Modificador
            )
            VALUES (
                @Id_Venta, @Id_Producto, @Id_Bodega, @Cantidad,
                @Precio_Unitario_Al_Momento_Venta, @Subtotal, COALESCE(@Id_Estado, 1),
                GETDATE(), GETDATE(), @Id_Creador, @Id_Modificador
            );

            SET @O_Num = SCOPE_IDENTITY();

            -- Solo el movimiento. El trigger descuenta el stock y corrige
            -- Stock_Anterior/Stock_Actual. NO hacer UPDATE aqui.
            INSERT INTO Tbl_Movimientos_Inventario (
                Id_Producto, Id_Bodega, Id_Bodega_Producto, Id_Tipo_Movimiento,
                Cantidad, Stock_Anterior, Stock_Actual, Costo_Unitario,
                Referencia, Observaciones, Fecha_Movimiento, Id_Usuario_Responsable
            )
            VALUES (
                @Id_Producto, @Id_Bodega, @Id_Bodega_Producto, 2,
                @Cantidad, @StockAnterior, @StockAnterior - @Cantidad, 0,
                'Venta #' + CAST(@Id_Venta AS VARCHAR),
                'Venta desde sistema', GETDATE(), @Id_Creador
            );

            SET @O_Msg = 'Detalle registrado correctamente.';
            COMMIT;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK;
            SET @O_Msg = ERROR_MESSAGE();
            SET @O_Num = -1;
        END CATCH
    END

    ELSE IF @Mode = 'UPD'
    BEGIN
        IF @Id_Detalle IS NULL
        BEGIN
            SET @O_Msg = 'Id_Detalle requerido.';
            SET @O_Num = -1; RETURN;
        END

        -- Editar un detalle ya confirmado moveria stock sin dejar rastro
        -- en el kardex. Se anula y se vuelve a registrar.
        SET @O_Msg = 'Un detalle de venta confirmado no se edita: anule la linea y registre una nueva para que el kardex quede consistente.';
        SET @O_Num = -1;
        RETURN;
    END

    ELSE IF @Mode = 'DEL'
    BEGIN
        IF @Id_Detalle IS NULL
        BEGIN
            SET @O_Msg = 'Id_Detalle requerido para anular.';
            SET @O_Num = -1; RETURN;
        END

        DECLARE @dv_Producto INT, @dv_Bodega INT, @dv_Cantidad INT,
                @dv_Estado INT, @dv_Venta INT, @dv_BodProd INT;

        SELECT @dv_Producto = Id_Producto, @dv_Bodega = Id_Bodega,
               @dv_Cantidad = Cantidad,    @dv_Estado = Id_Estado,
               @dv_Venta    = Id_Venta
        FROM Tbl_Detalle_Venta WHERE Id_Detalle = @Id_Detalle;

        IF @dv_Producto IS NULL
        BEGIN
            SET @O_Msg = 'El detalle no existe.';
            SET @O_Num = -1; RETURN;
        END

        IF @dv_Estado = 3
        BEGIN
            SET @O_Msg = 'El detalle ya esta anulado.';
            SET @O_Num = -1; RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            SELECT @dv_BodProd = Id_Bodega_Producto
            FROM Tbl_Bodega_Producto WITH (UPDLOCK, HOLDLOCK)
            WHERE Id_Bodega = @dv_Bodega AND Id_Producto = @dv_Producto;

            UPDATE Tbl_Detalle_Venta
            SET Id_Estado          = 3,
                Fecha_Modificacion = GETDATE(),
                Id_Modificador     = @Id_Modificador
            WHERE Id_Detalle = @Id_Detalle;

            -- Devolver la mercaderia al inventario (tipo 5 = devolucion)
            IF @dv_BodProd IS NOT NULL
                INSERT INTO Tbl_Movimientos_Inventario (
                    Id_Producto, Id_Bodega, Id_Bodega_Producto, Id_Tipo_Movimiento,
                    Cantidad, Stock_Anterior, Stock_Actual, Costo_Unitario,
                    Referencia, Observaciones, Fecha_Movimiento, Id_Usuario_Responsable
                )
                VALUES (
                    @dv_Producto, @dv_Bodega, @dv_BodProd, 5,
                    @dv_Cantidad, 0, 0, 0,
                    'Anulacion linea venta #' + CAST(@dv_Venta AS VARCHAR),
                    'Stock devuelto por anulacion de linea', GETDATE(), @Id_Modificador
                );

            SET @O_Num = @Id_Detalle;
            SET @O_Msg = 'Detalle anulado y stock devuelto.';
            COMMIT;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK;
            SET @O_Msg = ERROR_MESSAGE();
            SET @O_Num = -1;
        END CATCH
    END

    ELSE IF @Mode IN ('LST', 'FIL')
    BEGIN
        SELECT
            dv.Id_Detalle, dv.Id_Venta, v.Total AS Total_Venta_General,
            dv.Id_Producto, p.Nombre AS Producto, dv.Id_Bodega, b.Nombre_Bodega,
            dv.Cantidad, dv.Precio_Unitario_Al_Momento_Venta, dv.Subtotal,
            dv.Id_Estado, es.Estado, dv.Fecha_Creacion, dv.Fecha_Modificacion,
            dv.Id_Creador, dv.Id_Modificador
        FROM Tbl_Detalle_Venta dv
        JOIN Tbl_Ventas   v  ON dv.Id_Venta    = v.Id_Venta
        JOIN Tbl_Producto p  ON dv.Id_Producto = p.Id_Producto
        JOIN Cls_Estados  es ON dv.Id_Estado   = es.Id_Estado
        LEFT JOIN Tbl_Bodega b ON b.Id_Bodega  = dv.Id_Bodega
        WHERE @Mode = 'LST'
           OR CAST(dv.Id_Detalle AS VARCHAR) = @Filtro
           OR CAST(dv.Id_Venta   AS VARCHAR) = @Filtro
           OR p.Nombre LIKE '%' + @Filtro + '%';

        SET @O_Msg = 'Consulta de detalle de venta.';
        SET @O_Num = 0;
    END

    ELSE
    BEGIN
        SET @O_Msg = 'Modo no reconocido.';
        SET @O_Num = -1;
    END
END
GO
PRINT 'PASO 4: sp_Tbl_Detalle_Venta actualizado (sin UPDATE manual, con UPDLOCK y precio de servidor).';
GO

/* =====================================================================
   PASO 5 - sp_Tbl_Ventas modo DEL (anular venta)
   ---------------------------------------------------------------------
   Cambios:
     - Cursor reemplazado por INSERT...SELECT set-based. Esto elimina de
       raiz el bug de @StockAnterior: en T-SQL, "SELECT @var = col" deja
       la variable con el valor de la vuelta anterior si no encuentra
       filas, y se estaba escribiendo ese valor fantasma en el kardex.
     - Ya no hace UPDATE manual del stock
     - Envia Id_Bodega_Producto (antes la devolucion no se aplicaba via
       trigger, solo por el UPDATE manual)
   Los modos INS/UPD/LST/FIL se conservan igual salvo la validacion de
   total, que ahora se recalcula desde los detalles.
   ===================================================================== */
CREATE OR ALTER PROC sp_Tbl_Ventas
    @Mode            VARCHAR(3)    = NULL,
    @O_Msg           VARCHAR(255)  = NULL OUTPUT,
    @O_Num           INT           = NULL OUTPUT,
    @Id_Venta        INT           = NULL,
    @Fecha           DATETIME      = NULL,
    @Id_Cliente      INT           = NULL,
    @Id_Empleado     INT           = NULL,
    @Id_Metodo_Pago  INT           = NULL,
    @Total           DECIMAL(12,2) = NULL,
    @Id_Estado       INT           = NULL,
    @Id_Creador      INT           = NULL,
    @Id_Modificador  INT           = NULL,
    @Filtro          VARCHAR(100)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Mode = 'INS'
    BEGIN
        IF @Id_Cliente IS NULL OR @Id_Estado IS NULL OR @Id_Creador IS NULL
        BEGIN
            SET @O_Msg = 'Faltan datos para registrar la venta.';
            SET @O_Num = -1; RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Tbl_Cliente WHERE Id_Cliente = @Id_Cliente)
        BEGIN
            SET @O_Msg = 'El cliente especificado no existe.';
            SET @O_Num = -1; RETURN;
        END

        IF @Id_Metodo_Pago IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM Cls_Metodos_Pago WHERE Id_Metodo_Pago = @Id_Metodo_Pago)
        BEGIN
            SET @O_Msg = 'El metodo de pago especificado no existe.';
            SET @O_Num = -1; RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Cls_Estados WHERE Id_Estado = @Id_Estado)
        BEGIN
            SET @O_Msg = 'El estado especificado no existe.';
            SET @O_Num = -1; RETURN;
        END

        -- El empleado se deduce del usuario que crea, no se acepta del cliente.
        SELECT @Id_Empleado = e.Id_Empleado
        FROM Tbl_Usuarios u
        JOIN Tbl_Datos_Personales dp ON u.Id_Persona = dp.Id_Persona
        JOIN Tbl_Empleado e          ON dp.Id_Persona = e.Id_Persona
        WHERE u.Id_Usuario = @Id_Creador;

        BEGIN TRY
            BEGIN TRAN;
            INSERT INTO Tbl_Ventas (
                Fecha, Id_Cliente, Id_Empleado, Id_Metodo_Pago, Total,
                Id_Estado, Fecha_Creacion, Fecha_Modificacion, Id_Creador, Id_Modificador
            )
            VALUES (
                COALESCE(@Fecha, GETDATE()), @Id_Cliente, @Id_Empleado, @Id_Metodo_Pago,
                ISNULL(@Total, 0), @Id_Estado, GETDATE(), GETDATE(),
                @Id_Creador, ISNULL(@Id_Modificador, @Id_Creador)
            );
            SET @O_Num = SCOPE_IDENTITY();
            SET @O_Msg = 'Venta registrada correctamente.';
            COMMIT;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK;
            SET @O_Msg = ERROR_MESSAGE();
            SET @O_Num = -1;
        END CATCH
    END

    ELSE IF @Mode = 'UPD'
    BEGIN
        IF @Id_Venta IS NULL
        BEGIN
            SET @O_Msg = 'Id_Venta requerido.';
            SET @O_Num = -1; RETURN;
        END

        IF EXISTS (SELECT 1 FROM Tbl_Ventas WHERE Id_Venta = @Id_Venta AND Id_Estado = 3)
        BEGIN
            SET @O_Msg = 'No se puede modificar una venta anulada.';
            SET @O_Num = -1; RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;
            UPDATE Tbl_Ventas
            SET Fecha              = COALESCE(@Fecha,          Fecha),
                Id_Cliente         = COALESCE(@Id_Cliente,     Id_Cliente),
                Id_Metodo_Pago     = COALESCE(@Id_Metodo_Pago, Id_Metodo_Pago),
                Id_Estado          = COALESCE(@Id_Estado,      Id_Estado),
                Fecha_Modificacion = GETDATE(),
                Id_Modificador     = COALESCE(@Id_Modificador, Id_Modificador)
            WHERE Id_Venta = @Id_Venta;

            -- El total NUNCA se toma del parametro: se recalcula.
            UPDATE v
            SET v.Total = ISNULL((SELECT SUM(dv.Subtotal) FROM Tbl_Detalle_Venta dv
                                   WHERE dv.Id_Venta = @Id_Venta AND dv.Id_Estado <> 3), 0)
            FROM Tbl_Ventas v WHERE v.Id_Venta = @Id_Venta;

            SET @O_Num = @Id_Venta;
            SET @O_Msg = 'Venta actualizada correctamente.';
            COMMIT;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK;
            SET @O_Msg = ERROR_MESSAGE();
            SET @O_Num = -1;
        END CATCH
    END

    ELSE IF @Mode = 'DEL'
    BEGIN
        IF @Id_Venta IS NULL OR @Id_Modificador IS NULL
        BEGIN
            SET @O_Msg = 'Id_Venta e Id_Modificador requeridos.';
            SET @O_Num = -1; RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Tbl_Ventas WHERE Id_Venta = @Id_Venta)
        BEGIN
            SET @O_Msg = 'La venta no existe.';
            SET @O_Num = -1; RETURN;
        END

        IF EXISTS (SELECT 1 FROM Tbl_Ventas WHERE Id_Venta = @Id_Venta AND Id_Estado = 3)
        BEGIN
            SET @O_Msg = 'La venta ya se encuentra anulada.';
            SET @O_Num = -1; RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            -- Set-based: una sola sentencia devuelve todo el inventario.
            -- Sin cursor no hay variables que arrastren valores viejos.
            INSERT INTO Tbl_Movimientos_Inventario (
                Id_Producto, Id_Bodega, Id_Bodega_Producto, Id_Tipo_Movimiento,
                Cantidad, Stock_Anterior, Stock_Actual, Costo_Unitario,
                Referencia, Observaciones, Fecha_Movimiento, Id_Usuario_Responsable
            )
            SELECT  dv.Id_Producto,
                    dv.Id_Bodega,
                    bp.Id_Bodega_Producto,
                    5,                          -- Devolucion por anulacion
                    SUM(dv.Cantidad),
                    0, 0, 0,                    -- el trigger los reescribe
                    'Anulacion Venta #' + CAST(@Id_Venta AS VARCHAR),
                    'Stock devuelto por anulacion',
                    GETDATE(),
                    @Id_Modificador
            FROM Tbl_Detalle_Venta dv
            JOIN Tbl_Bodega_Producto bp
                   ON bp.Id_Bodega   = dv.Id_Bodega
                  AND bp.Id_Producto = dv.Id_Producto
            WHERE dv.Id_Venta  = @Id_Venta
              AND dv.Id_Estado <> 3
            GROUP BY dv.Id_Producto, dv.Id_Bodega, bp.Id_Bodega_Producto;

            UPDATE Tbl_Detalle_Venta
            SET Id_Estado = 3, Fecha_Modificacion = GETDATE(), Id_Modificador = @Id_Modificador
            WHERE Id_Venta = @Id_Venta;

            UPDATE Tbl_Ventas
            SET Id_Estado = 3, Fecha_Modificacion = GETDATE(), Id_Modificador = @Id_Modificador
            WHERE Id_Venta = @Id_Venta;

            SET @O_Num = @Id_Venta;
            SET @O_Msg = 'Venta anulada correctamente. El inventario fue restaurado.';
            COMMIT;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK;
            SET @O_Msg = ERROR_MESSAGE();
            SET @O_Num = -1;
        END CATCH
    END

    ELSE IF @Mode IN ('LST', 'FIL')
    BEGIN
        SELECT
            v.Id_Venta, v.Numero_Factura, v.Fecha, v.Id_Cliente,
            LTRIM(RTRIM(ISNULL(dc.Primer_Nombre,'') + ' ' + ISNULL(dc.Primer_Apellido,''))) AS Cliente,
            v.Id_Empleado,
            ISNULL(NULLIF(LTRIM(RTRIM(ISNULL(de.Primer_Nombre,'') + ' ' + ISNULL(de.Primer_Apellido,''))),''),
                   'Administrador del Sistema') AS Empleado,
            v.Id_Metodo_Pago, mp.Descripcion AS Metodo_Pago,
            v.Total, v.Id_Estado, es.Estado,
            v.Fecha_Creacion, v.Fecha_Modificacion, v.Id_Creador, v.Id_Modificador
        FROM Tbl_Ventas v
        JOIN Tbl_Cliente c                ON v.Id_Cliente     = c.Id_Cliente
        JOIN Tbl_Datos_Personales dc      ON c.Id_Persona     = dc.Id_Persona
        LEFT JOIN Tbl_Empleado e          ON v.Id_Empleado    = e.Id_Empleado
        LEFT JOIN Tbl_Datos_Personales de ON e.Id_Persona     = de.Id_Persona
        LEFT JOIN Cls_Metodos_Pago mp     ON v.Id_Metodo_Pago = mp.Id_Metodo_Pago
        JOIN Cls_Estados es               ON v.Id_Estado      = es.Id_Estado
        WHERE @Mode = 'LST'
           OR CAST(v.Id_Venta AS VARCHAR) = @Filtro
           OR v.Numero_Factura   LIKE '%' + @Filtro + '%'
           OR dc.Primer_Nombre   LIKE '%' + @Filtro + '%'
           OR dc.Primer_Apellido LIKE '%' + @Filtro + '%'
           OR es.Estado          LIKE '%' + @Filtro + '%'
        ORDER BY v.Id_Venta DESC;

        SET @O_Msg = 'Consulta de ventas.';
        SET @O_Num = 0;
    END

    ELSE
    BEGIN
        SET @O_Msg = 'Modo no reconocido.';
        SET @O_Num = -1;
    END
END
GO
PRINT 'PASO 5: sp_Tbl_Ventas actualizado (DEL set-based, sin bug de variable, total recalculado).';
GO

/* =====================================================================
   PASO 6 - sp_Tbl_Compra modo DEL (anular compra)
   ---------------------------------------------------------------------
   ESTE ERA EL BUG QUE INFLABA EL INVENTARIO.
   El movimiento se insertaba sin Id_Bodega_Producto, el trigger no lo
   emparejaba, y el stock nunca bajaba: la compra quedaba anulada pero
   la mercaderia seguia contada.
   Ahora es set-based y vincula correctamente.
   ===================================================================== */
CREATE OR ALTER PROC sp_Tbl_Compra
    @Mode                     VARCHAR(3)    = NULL,
    @O_Msg                    VARCHAR(255)  = NULL OUTPUT,
    @O_Num                    INT           = NULL OUTPUT,
    @Id_Compra                INT           = NULL,
    @Id_Proveedor             INT           = NULL,
    @Numero_Factura_Proveedor VARCHAR(50)   = NULL,
    @Fecha_Compra             DATE          = NULL,
    @Total_Compra             DECIMAL(12,2) = NULL,
    @Id_Estado                INT           = NULL,
    @Id_Creador               INT           = NULL,
    @Id_Modificador           INT           = NULL,
    @Filtro                   VARCHAR(100)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Mode = 'INS'
    BEGIN
        IF @Id_Proveedor IS NULL OR @Id_Estado IS NULL
           OR @Id_Creador IS NULL OR @Id_Modificador IS NULL
        BEGIN
            SET @O_Msg = 'Faltan campos obligatorios.';
            SET @O_Num = -1; RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Tbl_Proveedor WHERE Id_Proveedor = @Id_Proveedor)
        BEGIN
            SET @O_Msg = 'El proveedor especificado no existe.';
            SET @O_Num = -1; RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;
            INSERT INTO Tbl_Compra (
                Id_Proveedor, Numero_Factura_Proveedor, Fecha_Compra,
                Total_Compra, Id_Estado, Fecha_Creacion, Fecha_Modificacion,
                Id_Creador, Id_Modificador
            )
            VALUES (
                @Id_Proveedor, @Numero_Factura_Proveedor, COALESCE(@Fecha_Compra, GETDATE()),
                ISNULL(@Total_Compra, 0), @Id_Estado, GETDATE(), GETDATE(),
                @Id_Creador, @Id_Modificador
            );
            SET @O_Num = CAST(SCOPE_IDENTITY() AS INT);
            SET @O_Msg = 'Compra registrada correctamente.';
            COMMIT;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK;
            SET @O_Msg = ERROR_MESSAGE();
            SET @O_Num = -1;
        END CATCH
    END

    ELSE IF @Mode = 'UPD'
    BEGIN
        IF @Id_Compra IS NULL
        BEGIN
            SET @O_Msg = 'Id_Compra requerido para actualizar.';
            SET @O_Num = -1; RETURN;
        END

        IF EXISTS (SELECT 1 FROM Tbl_Compra WHERE Id_Compra = @Id_Compra AND Id_Estado = 3)
        BEGIN
            SET @O_Msg = 'No se puede modificar una compra anulada.';
            SET @O_Num = -1; RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;
            UPDATE Tbl_Compra
            SET Id_Proveedor             = COALESCE(@Id_Proveedor,             Id_Proveedor),
                Numero_Factura_Proveedor = COALESCE(@Numero_Factura_Proveedor, Numero_Factura_Proveedor),
                Fecha_Compra             = COALESCE(@Fecha_Compra,             Fecha_Compra),
                Id_Estado                = COALESCE(@Id_Estado,                Id_Estado),
                Fecha_Modificacion       = GETDATE(),
                Id_Modificador           = COALESCE(@Id_Modificador,           Id_Modificador)
            WHERE Id_Compra = @Id_Compra;

            -- Total recalculado desde los detalles, no desde el parametro.
            UPDATE c
            SET c.Total_Compra = ISNULL((SELECT SUM(dc.Subtotal_Compra)
                                          FROM Tbl_Detalle_Compra dc
                                          WHERE dc.Id_Compra = @Id_Compra), 0)
            FROM Tbl_Compra c WHERE c.Id_Compra = @Id_Compra;

            SET @O_Num = @Id_Compra;
            SET @O_Msg = 'Compra actualizada correctamente.';
            COMMIT;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK;
            SET @O_Msg = ERROR_MESSAGE();
            SET @O_Num = -1;
        END CATCH
    END

    ELSE IF @Mode = 'DEL'
    BEGIN
        IF @Id_Compra IS NULL OR @Id_Modificador IS NULL
        BEGIN
            SET @O_Msg = 'Id_Compra e Id_Modificador requeridos.';
            SET @O_Num = -1; RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Tbl_Compra WHERE Id_Compra = @Id_Compra)
        BEGIN
            SET @O_Msg = 'La compra no existe.';
            SET @O_Num = -1; RETURN;
        END

        IF EXISTS (SELECT 1 FROM Tbl_Compra WHERE Id_Compra = @Id_Compra AND Id_Estado = 3)
        BEGIN
            SET @O_Msg = 'La compra ya se encuentra anulada.';
            SET @O_Num = -1; RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            -- Si el stock ya se vendio, la anulacion dejaria negativo.
            -- Mejor avisar con un mensaje claro que dejar que reviente
            -- el trigger con un error generico.
            IF EXISTS (
                SELECT 1
                FROM Tbl_Detalle_Compra dc
                JOIN Tbl_Bodega_Producto bp
                       ON bp.Id_Bodega = dc.Id_Bodega AND bp.Id_Producto = dc.Id_Producto
                WHERE dc.Id_Compra = @Id_Compra
                GROUP BY bp.Id_Bodega_Producto, bp.Cantidad
                HAVING bp.Cantidad < SUM(dc.Cantidad)
            )
            BEGIN
                IF @@TRANCOUNT > 0 ROLLBACK;
                SET @O_Msg = 'No se puede anular: parte de esta mercaderia ya fue vendida y el stock quedaria en negativo.';
                SET @O_Num = -1; RETURN;
            END

            -- CORREGIDO: ahora si vincula Id_Bodega_Producto, por lo que
            -- el trigger descuenta de verdad. Antes esto no hacia nada.
            INSERT INTO Tbl_Movimientos_Inventario (
                Id_Producto, Id_Bodega, Id_Bodega_Producto, Id_Tipo_Movimiento,
                Cantidad, Stock_Anterior, Stock_Actual, Costo_Unitario,
                Referencia, Observaciones, Fecha_Movimiento, Id_Usuario_Responsable
            )
            SELECT  dc.Id_Producto,
                    dc.Id_Bodega,
                    bp.Id_Bodega_Producto,
                    4,                          -- Salida por anulacion de compra
                    SUM(dc.Cantidad),
                    0, 0, 0,
                    'Anulacion Compra #' + CAST(@Id_Compra AS VARCHAR),
                    'Stock retirado por anulacion de compra',
                    GETDATE(),
                    @Id_Modificador
            FROM Tbl_Detalle_Compra dc
            JOIN Tbl_Bodega_Producto bp
                   ON bp.Id_Bodega = dc.Id_Bodega AND bp.Id_Producto = dc.Id_Producto
            WHERE dc.Id_Compra = @Id_Compra
            GROUP BY dc.Id_Producto, dc.Id_Bodega, bp.Id_Bodega_Producto;

            UPDATE Tbl_Compra
            SET Id_Estado = 3, Fecha_Modificacion = GETDATE(), Id_Modificador = @Id_Modificador
            WHERE Id_Compra = @Id_Compra;

            SET @O_Num = @Id_Compra;
            SET @O_Msg = 'Compra anulada y stock retirado correctamente.';
            COMMIT;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK;
            SET @O_Msg = ERROR_MESSAGE();
            SET @O_Num = -1;
        END CATCH
    END

    ELSE IF @Mode IN ('LST', 'FIL')
    BEGIN
        SELECT
            c.Id_Compra, c.Id_Proveedor,
            LTRIM(RTRIM(ISNULL(dp.Primer_Nombre,'') + ' ' + ISNULL(dp.Primer_Apellido,''))) AS Proveedor,
            c.Numero_Factura_Proveedor, c.Fecha_Compra, c.Total_Compra,
            c.Id_Estado, es.Estado, c.Fecha_Creacion, c.Fecha_Modificacion,
            c.Id_Creador, c.Id_Modificador
        FROM Tbl_Compra c
        JOIN Tbl_Proveedor        pr ON c.Id_Proveedor = pr.Id_Proveedor
        JOIN Tbl_Datos_Personales dp ON pr.Id_Persona  = dp.Id_Persona
        JOIN Cls_Estados          es ON c.Id_Estado    = es.Id_Estado
        WHERE @Mode = 'LST'
           OR CAST(c.Id_Compra AS VARCHAR)  = @Filtro
           OR dp.Primer_Nombre           LIKE '%' + @Filtro + '%'
           OR dp.Primer_Apellido         LIKE '%' + @Filtro + '%'
           OR c.Numero_Factura_Proveedor LIKE '%' + @Filtro + '%'
           OR es.Estado                  LIKE '%' + @Filtro + '%'
        ORDER BY c.Id_Compra DESC;

        SET @O_Msg = 'Consulta de compras.';
        SET @O_Num = 0;
    END

    ELSE
    BEGIN
        SET @O_Msg = 'Modo no reconocido.';
        SET @O_Num = -1;
    END
END
GO
PRINT 'PASO 6: sp_Tbl_Compra actualizado. La anulacion de compra YA descuenta stock.';
GO

/* =====================================================================
   PASO 7 - sp_Tbl_Detalle_Compra: endurecer el INS
   ---------------------------------------------------------------------
   Ya vinculaba bien Id_Bodega_Producto. Los cambios son:
     - El tipo de movimiento se buscaba por texto ('Compra a Proveedor');
       si alguien renombraba el catalogo devolvia NULL y el INSERT
       reventaba con un error opaco. Ahora valida.
     - El subtotal se recalcula siempre en servidor.
     - El total de la compra se sincroniza tras cada linea.
   ===================================================================== */
CREATE OR ALTER PROC sp_Tbl_Detalle_Compra
    @Mode                   VARCHAR(3)    = NULL,
    @O_Msg                  VARCHAR(255)  = NULL OUTPUT,
    @O_Num                  INT           = NULL OUTPUT,
    @Id_Detalle_Compra      INT           = NULL,
    @Id_Compra              INT           = NULL,
    @Id_Bodega              INT           = NULL,
    @Id_Producto            INT           = NULL,
    @Cantidad               INT           = NULL,
    @Precio_Unitario_Compra DECIMAL(12,2) = NULL,
    @Subtotal_Compra        DECIMAL(12,2) = NULL,
    @Id_Creador             INT           = NULL,
    @Id_Modificador         INT           = NULL,
    @Filtro                 VARCHAR(100)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Id_Modificador IS NULL SET @Id_Modificador = @Id_Creador;

    IF @Mode = 'INS'
    BEGIN
        IF @Id_Compra IS NULL OR @Id_Producto IS NULL OR @Id_Bodega IS NULL
           OR @Cantidad IS NULL OR @Precio_Unitario_Compra IS NULL OR @Id_Creador IS NULL
        BEGIN
            SET @O_Msg = 'Faltan datos obligatorios.';
            SET @O_Num = -1; RETURN;
        END

        IF @Cantidad <= 0 OR @Precio_Unitario_Compra < 0
        BEGIN
            SET @O_Msg = 'Cantidad debe ser mayor a cero y el precio no puede ser negativo.';
            SET @O_Num = -1; RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Tbl_Compra WHERE Id_Compra = @Id_Compra AND Id_Estado <> 3)
        BEGIN
            SET @O_Msg = 'La compra no existe o esta anulada.';
            SET @O_Num = -1; RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Tbl_Producto WHERE Id_Producto = @Id_Producto AND Id_Estado = 1)
        BEGIN
            SET @O_Msg = 'El producto no existe o esta inactivo.';
            SET @O_Num = -1; RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Tbl_Bodega WHERE Id_Bodega = @Id_Bodega AND Id_Estado = 1)
        BEGIN
            SET @O_Msg = 'La bodega no existe o esta inactiva.';
            SET @O_Num = -1; RETURN;
        END

        SET @Subtotal_Compra = @Cantidad * @Precio_Unitario_Compra;

        DECLARE @Id_Tipo_Movimiento INT;
        SELECT TOP 1 @Id_Tipo_Movimiento = Id_Tipo_Movimiento
        FROM Cls_Tipo_Movimiento
        WHERE Descripcion = 'Compra a Proveedor' AND Operacion IN ('SUMA','Entrada');

        IF @Id_Tipo_Movimiento IS NULL
        BEGIN
            SET @O_Msg = 'No existe el tipo de movimiento "Compra a Proveedor" con operacion de entrada. Revise Cls_Tipo_Movimiento.';
            SET @O_Num = -1; RETURN;
        END

        DECLARE @Id_Bodega_Producto INT, @Stock_Anterior INT;

        BEGIN TRY
            BEGIN TRAN;

            SELECT @Id_Bodega_Producto = Id_Bodega_Producto,
                   @Stock_Anterior     = Cantidad
            FROM Tbl_Bodega_Producto WITH (UPDLOCK, HOLDLOCK)
            WHERE Id_Bodega = @Id_Bodega AND Id_Producto = @Id_Producto;

            IF @Id_Bodega_Producto IS NULL
            BEGIN
                INSERT INTO Tbl_Bodega_Producto (
                    Id_Bodega, Id_Producto, Cantidad,
                    Fecha_Creacion, Fecha_Modificacion, Id_Creador, Id_Modificador
                )
                VALUES (@Id_Bodega, @Id_Producto, 0, GETDATE(), GETDATE(), @Id_Creador, @Id_Modificador);
                SET @Id_Bodega_Producto = SCOPE_IDENTITY();
                SET @Stock_Anterior     = 0;
            END

            INSERT INTO Tbl_Detalle_Compra (
                Id_Compra, Id_Producto, Id_Bodega, Cantidad,
                Precio_Unitario_Compra, Subtotal_Compra,
                Fecha_Creacion, Fecha_Modificacion, Id_Creador, Id_Modificador
            )
            VALUES (
                @Id_Compra, @Id_Producto, @Id_Bodega, @Cantidad,
                @Precio_Unitario_Compra, @Subtotal_Compra,
                GETDATE(), GETDATE(), @Id_Creador, @Id_Modificador
            );
            SET @O_Num = SCOPE_IDENTITY();

            -- El trigger suma el stock y corrige Stock_Anterior/Actual.
            INSERT INTO Tbl_Movimientos_Inventario (
                Id_Producto, Id_Bodega, Id_Bodega_Producto, Id_Tipo_Movimiento,
                Cantidad, Stock_Anterior, Stock_Actual, Costo_Unitario,
                Referencia, Observaciones, Fecha_Movimiento, Id_Usuario_Responsable
            )
            VALUES (
                @Id_Producto, @Id_Bodega, @Id_Bodega_Producto, @Id_Tipo_Movimiento,
                @Cantidad, @Stock_Anterior, @Stock_Anterior + @Cantidad,
                @Precio_Unitario_Compra,
                'Compra #' + CAST(@Id_Compra AS VARCHAR),
                'Entrada por compra', GETDATE(), @Id_Creador
            );

            -- Mantener el total de la cabecera sincronizado.
            UPDATE c
            SET c.Total_Compra = ISNULL((SELECT SUM(dc.Subtotal_Compra)
                                          FROM Tbl_Detalle_Compra dc
                                          WHERE dc.Id_Compra = @Id_Compra), 0),
                c.Fecha_Modificacion = GETDATE()
            FROM Tbl_Compra c WHERE c.Id_Compra = @Id_Compra;

            SET @O_Msg = 'Detalle registrado y stock actualizado.';
            COMMIT;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK;
            SET @O_Msg = ERROR_MESSAGE();
            SET @O_Num = -1;
        END CATCH
    END

    ELSE IF @Mode = 'UPD'
    BEGIN
        SET @O_Msg = 'Un detalle de compra confirmado no se edita: anule la compra y registrela de nuevo para no descuadrar el kardex.';
        SET @O_Num = -1;
        RETURN;
    END

    ELSE IF @Mode = 'DEL'
    BEGIN
        SET @O_Msg = 'No se elimina un detalle de compra individualmente. Use la anulacion de compra (sp_Tbl_Compra modo DEL) para que el stock se retire correctamente.';
        SET @O_Num = -1;
        RETURN;
    END

    ELSE IF @Mode IN ('LST', 'FIL')
    BEGIN
        SELECT
            dc.Id_Detalle_Compra, dc.Id_Compra, c.Total_Compra,
            dc.Id_Producto, p.Nombre AS Producto,
            dc.Id_Bodega, b.Nombre_Bodega,
            dc.Cantidad, dc.Precio_Unitario_Compra, dc.Subtotal_Compra,
            dc.Fecha_Creacion, dc.Fecha_Modificacion, dc.Id_Creador, dc.Id_Modificador
        FROM Tbl_Detalle_Compra dc
        JOIN Tbl_Compra   c ON dc.Id_Compra   = c.Id_Compra
        JOIN Tbl_Producto p ON dc.Id_Producto = p.Id_Producto
        JOIN Tbl_Bodega   b ON dc.Id_Bodega   = b.Id_Bodega
        WHERE @Mode = 'LST'
           OR CAST(dc.Id_Detalle_Compra AS VARCHAR) = @Filtro
           OR CAST(dc.Id_Compra         AS VARCHAR) = @Filtro
           OR p.Nombre        LIKE '%' + @Filtro + '%'
           OR b.Nombre_Bodega LIKE '%' + @Filtro + '%';

        SET @O_Msg = 'Consulta de detalle de compras.';
        SET @O_Num = 0;
    END

    ELSE
    BEGIN
        SET @O_Msg = 'Modo no reconocido.';
        SET @O_Num = -1;
    END
END
GO
PRINT 'PASO 7: sp_Tbl_Detalle_Compra endurecido.';
GO

PRINT '';
PRINT '=====================================================================';
PRINT ' 002 COMPLETADO';
PRINT ' Vuelva a correr 000_auditoria_stock.sql: la consulta 2 (movimientos';
PRINT ' huerfanos) no debe crecer mas a partir de ahora.';
PRINT ' Los descuadres YA existentes hay que corregirlos a mano con un';
PRINT ' ajuste de inventario; este script no toca datos historicos.';
PRINT '=====================================================================';
GO
