USE NicaTek;
GO

CREATE OR ALTER PROC sp_Tbl_Movimientos_Inventario
    @Mode VARCHAR(3) = NULL,
    @O_Msg VARCHAR(255) = NULL OUTPUT,
    @O_Num INT = NULL OUTPUT,

    @Id_Movimiento INT = NULL,
    @Id_Producto INT = NULL,
    @Id_Bodega INT = NULL,
    @Id_Tipo_Movimiento INT = NULL,
    @Cantidad INT = NULL,
    @Stock_Anterior INT = NULL,
    @Stock_Actual INT = NULL,   
    @Costo_Unitario DECIMAL(18,2) = NULL,
    @Referencia VARCHAR(100) = NULL,
    @Observaciones VARCHAR(255) = NULL,
    @Id_Usuario_Responsable INT = NULL,
    
    @Filtro VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Mode = 'INS'
    BEGIN
        -- 1. Validaciones de entrada
        IF @Id_Producto IS NULL OR @Id_Bodega IS NULL OR @Id_Tipo_Movimiento IS NULL 
           OR @Cantidad IS NULL OR @Id_Usuario_Responsable IS NULL
        BEGIN
            SET @O_Msg = 'Faltan datos obligatorios (Producto, Bodega, Tipo, Cantidad, Usuario).';
            SET @O_Num = -1;
            RETURN;
        END

        -- 2. Variables locales para cálculo interno
        DECLARE @RealStockAnterior INT = 0;
        DECLARE @RealStockActual INT = 0;
        DECLARE @Operacion VARCHAR(10);

        BEGIN TRY
            BEGIN TRAN;

            -- 3. Obtener el stock actual de la bodega y el tipo de operación (SUMA/RESTA)
            SELECT @RealStockAnterior = ISNULL(Cantidad, 0) FROM Tbl_Bodega WHERE Id_Bodega = @Id_Bodega;
            SELECT @Operacion = Operacion FROM Cls_Tipo_Movimiento WHERE Id_Tipo_Movimiento = @Id_Tipo_Movimiento;

            -- 4. Calcular el Stock_Actual que quedará en el registro del Kardex
            IF @Operacion = 'SUMA'
                SET @RealStockActual = @RealStockAnterior + @Cantidad;
            ELSE IF @Operacion = 'RESTA'
                SET @RealStockActual = @RealStockAnterior - @Cantidad;
            ELSE
                SET @RealStockActual = @RealStockAnterior; -- En caso de ajustes neutros

            -- 5. Insertar el registro con la "foto" precisa del inventario
            INSERT INTO Tbl_Movimientos_Inventario (
                Id_Producto, 
                Id_Bodega, 
                Id_Tipo_Movimiento, 
                Cantidad, 
                Stock_Anterior, 
                Stock_Actual, 
                Costo_Unitario, 
                Referencia, 
                Observaciones, 
                Fecha_Movimiento, 
                Id_Usuario_Responsable,
                Fecha_Creacion
            )
            VALUES (
                @Id_Producto, 
                @Id_Bodega, 
                @Id_Tipo_Movimiento, 
                @Cantidad, 
                @RealStockAnterior, 
                @RealStockActual, 
                ISNULL(@Costo_Unitario, 0), 
                @Referencia, 
                @Observaciones, 
                GETDATE(), 
                @Id_Usuario_Responsable,
                GETDATE()
            );

            SET @O_Num = SCOPE_IDENTITY();
            SET @O_Msg = 'Movimiento registrado. El stock físico será actualizado por el Trigger.';
            
            COMMIT TRAN;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRAN;
            SET @O_Msg = ERROR_MESSAGE();
            SET @O_Num = -1;
        END CATCH
    END

    ELSE IF @Mode = 'LST'
    BEGIN
        SELECT 
            m.Id_Movimiento,
            m.Fecha_Movimiento,
            m.Id_Producto,
            p.Nombre AS Producto,
            m.Id_Tipo_Movimiento,
            tm.Descripcion AS Tipo_Movimiento, 
            m.Cantidad,
            m.Stock_Anterior,
            m.Stock_Actual,
            m.Id_Bodega,
            m.Costo_Unitario,
            m.Referencia,
            m.Observaciones,
            m.Id_Usuario_Responsable,
            u.Nombre_Usuario AS Responsable
        FROM Tbl_Movimientos_Inventario m
        LEFT JOIN Tbl_Producto p ON m.Id_Producto = p.Id_Producto
        LEFT JOIN Cls_Tipo_Movimiento tm ON m.Id_Tipo_Movimiento = tm.Id_Tipo_Movimiento
        LEFT JOIN Tbl_Usuarios u ON m.Id_Usuario_Responsable = u.Id_Usuario
        ORDER BY m.Fecha_Movimiento DESC;

        SET @O_Msg = 'Kardex recuperado.';
        SET @O_Num = 0;
    END

    ELSE IF @Mode = 'FIL'
    BEGIN
        SET @Filtro = ISNULL(@Filtro, '');

        SELECT 
            m.Id_Movimiento,
            m.Fecha_Movimiento,
            m.Id_Producto,
            p.Nombre AS Producto,
            m.Id_Tipo_Movimiento,
            tm.Descripcion AS Tipo_Movimiento, 
            m.Cantidad,
            m.Stock_Anterior,
            m.Stock_Actual,
            m.Id_Bodega,
            m.Costo_Unitario,
            m.Referencia,
            m.Observaciones,
            m.Id_Usuario_Responsable,
            u.Nombre_Usuario AS Responsable
        FROM Tbl_Movimientos_Inventario m
        LEFT JOIN Tbl_Producto p ON m.Id_Producto = p.Id_Producto
        LEFT JOIN Cls_Tipo_Movimiento tm ON m.Id_Tipo_Movimiento = tm.Id_Tipo_Movimiento
        LEFT JOIN Tbl_Usuarios u ON m.Id_Usuario_Responsable = u.Id_Usuario
        WHERE p.Nombre LIKE '%' + @Filtro + '%'
           OR m.Referencia LIKE '%' + @Filtro + '%'
           OR tm.Descripcion LIKE '%' + @Filtro + '%'
        ORDER BY m.Fecha_Movimiento DESC;

        SET @O_Msg = 'Filtro aplicado.';
        SET @O_Num = 0;
    END
    
    ELSE
    BEGIN
        SET @O_Msg = 'Opción no válida.';
        SET @O_Num = -1;
    END
END
GO