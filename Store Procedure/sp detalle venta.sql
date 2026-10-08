USE NicaTek;
GO

CREATE OR ALTER PROC sp_Tbl_Detalle_Venta
    @Mode                            VARCHAR(3)    = NULL,
    @O_Msg                           VARCHAR(255)  = NULL OUTPUT,
    @O_Num                           INT           = NULL OUTPUT,
    @Id_Detalle                      INT           = NULL,
    @Id_Venta                        INT           = NULL,
    @Id_Producto                     INT           = NULL,
    @Id_Bodega                       INT           = NULL,
    @Cantidad                        INT           = NULL,
    @Precio_Unitario_Al_Momento_Venta DECIMAL(12,2) = NULL,
    @Subtotal                        DECIMAL(12,2) = NULL,
    @Id_Estado                       INT           = NULL,
    @Id_Creador                      INT           = NULL,
    @Id_Modificador                  INT           = NULL,
    @Filtro                          VARCHAR(100)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Id_Modificador IS NULL
        SET @Id_Modificador = @Id_Creador;

    IF @Mode = 'INS'
    BEGIN
        IF @Id_Venta IS NULL OR @Id_Producto IS NULL OR @Cantidad IS NULL
           OR @Precio_Unitario_Al_Momento_Venta IS NULL OR @Id_Creador IS NULL
        BEGIN
            SET @O_Msg = 'Faltan campos obligatorios en el Detalle.';
            SET @O_Num = -1;
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Tbl_Ventas WHERE Id_Venta = @Id_Venta)
        BEGIN
            SET @O_Msg = 'La venta especificada no existe.';
            SET @O_Num = -1;
            RETURN;
        END

        DECLARE @StockAnterior INT = 0;

        IF @Id_Bodega IS NOT NULL
        BEGIN
            SELECT @StockAnterior = Cantidad
            FROM Tbl_Bodega_Producto
            WHERE Id_Bodega   = @Id_Bodega
              AND Id_Producto = @Id_Producto;
        END
        ELSE
        BEGIN
            SELECT TOP 1
                   @Id_Bodega     = Id_Bodega,
                   @StockAnterior = Cantidad
            FROM Tbl_Bodega_Producto
            WHERE Id_Producto = @Id_Producto
            ORDER BY Cantidad DESC;
        END

        IF @Id_Bodega IS NULL
        BEGIN
            SET @O_Msg = 'El producto no tiene registro de inventario en bodega.';
            SET @O_Num = -1;
            RETURN;
        END

        IF @StockAnterior < @Cantidad
        BEGIN
            SET @O_Msg = 'Stock insuficiente. Disponible: ' + CAST(@StockAnterior AS VARCHAR);
            SET @O_Num = -1;
            RETURN;
        END

        IF @Subtotal IS NULL
            SET @Subtotal = @Cantidad * @Precio_Unitario_Al_Momento_Venta;

        BEGIN TRY
            BEGIN TRAN;

            INSERT INTO Tbl_Detalle_Venta (
                Id_Venta, Id_Producto, Id_Bodega, Cantidad,
                Precio_Unitario_Al_Momento_Venta,
                Subtotal, Id_Estado, Fecha_Creacion, Fecha_Modificacion,
                Id_Creador, Id_Modificador
            )
            VALUES (
                @Id_Venta, @Id_Producto, @Id_Bodega, @Cantidad,
                @Precio_Unitario_Al_Momento_Venta,
                @Subtotal, COALESCE(@Id_Estado, 1), GETDATE(), GETDATE(),
                @Id_Creador, @Id_Modificador
            );

            SET @O_Num = SCOPE_IDENTITY();

            DECLARE @StockActual INT = @StockAnterior - @Cantidad;

            UPDATE Tbl_Bodega_Producto
            SET Cantidad           = @StockActual,
                Fecha_Modificacion = GETDATE(),
                Id_Modificador     = @Id_Modificador
            WHERE Id_Bodega   = @Id_Bodega
              AND Id_Producto = @Id_Producto;

            INSERT INTO Tbl_Movimientos_Inventario (
                Id_Producto, Id_Bodega, Id_Tipo_Movimiento, Cantidad,
                Stock_Anterior, Stock_Actual, Costo_Unitario,
                Referencia, Observaciones, Fecha_Movimiento, Id_Usuario_Responsable
            )
            VALUES (
                @Id_Producto, @Id_Bodega, 2, @Cantidad,
                @StockAnterior, @StockActual, 0,
                'Venta #' + CAST(@Id_Venta AS VARCHAR),
                'Venta desde sistema', GETDATE(), @Id_Creador
            );

            SET @O_Msg = 'Detalle registrado correctamente.';
            COMMIT;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK;
            SET @O_Msg = ERROR_MESSAGE();
            SET @O_Num = 0;
        END CATCH
    END

    ELSE IF @Mode = 'UPD'
    BEGIN
        IF @Id_Detalle IS NULL
        BEGIN
            SET @O_Msg = 'Id_Detalle requerido.';
            SET @O_Num = -1;
            RETURN;
        END

        DECLARE @NuevaCant   INT;
        DECLARE @NuevoPrecio DECIMAL(12,2);

        SELECT @NuevaCant   = COALESCE(@Cantidad,                         Cantidad),
               @NuevoPrecio = COALESCE(@Precio_Unitario_Al_Momento_Venta, Precio_Unitario_Al_Momento_Venta)
        FROM Tbl_Detalle_Venta
        WHERE Id_Detalle = @Id_Detalle;

        IF @Subtotal IS NULL
            SET @Subtotal = @NuevaCant * @NuevoPrecio;

        BEGIN TRY
            BEGIN TRAN;

            UPDATE Tbl_Detalle_Venta
            SET Cantidad                         = COALESCE(@Cantidad,                        Cantidad),
                Id_Producto                      = COALESCE(@Id_Producto,                     Id_Producto),
                Precio_Unitario_Al_Momento_Venta = COALESCE(@Precio_Unitario_Al_Momento_Venta, Precio_Unitario_Al_Momento_Venta),
                Subtotal                         = @Subtotal,
                Id_Estado                        = COALESCE(@Id_Estado,                       Id_Estado),
                Fecha_Modificacion               = GETDATE(),
                Id_Modificador                   = @Id_Modificador
            WHERE Id_Detalle = @Id_Detalle;

            SET @O_Num = @Id_Detalle;
            SET @O_Msg = 'Detalle actualizado correctamente.';
            COMMIT;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK;
            SET @O_Msg = ERROR_MESSAGE();
            SET @O_Num = 0;
        END CATCH
    END

    ELSE IF @Mode = 'DEL'
    BEGIN
        IF @Id_Detalle IS NULL
        BEGIN
            SET @O_Msg = 'Id_Detalle requerido para anular.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            UPDATE Tbl_Detalle_Venta
            SET Id_Estado          = 2,
                Fecha_Modificacion = GETDATE(),
                Id_Modificador     = @Id_Modificador
            WHERE Id_Detalle = @Id_Detalle;

            SET @O_Num = @Id_Detalle;
            SET @O_Msg = 'Detalle anulado correctamente.';
            COMMIT;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK;
            SET @O_Msg = ERROR_MESSAGE();
            SET @O_Num = 0;
        END CATCH
    END

    ELSE IF @Mode = 'LST'
    BEGIN
        SELECT
            dv.Id_Detalle,
            dv.Id_Venta,
            v.Total AS Total_Venta_General,
            dv.Id_Producto,
            p.Nombre AS Producto,
            dv.Id_Bodega,
            dv.Cantidad,
            dv.Precio_Unitario_Al_Momento_Venta,
            dv.Subtotal,
            dv.Id_Estado,
            es.Estado,
            dv.Fecha_Creacion,
            dv.Fecha_Modificacion,
            dv.Id_Creador,
            dv.Id_Modificador
        FROM Tbl_Detalle_Venta dv
        JOIN Tbl_Ventas   v  ON dv.Id_Venta   = v.Id_Venta
        JOIN Tbl_Producto p  ON dv.Id_Producto = p.Id_Producto
        JOIN Cls_Estados  es ON dv.Id_Estado   = es.Id_Estado;

        SET @O_Msg = 'Listado de detalle de ventas.';
        SET @O_Num = 0;
    END

    ELSE IF @Mode = 'FIL'
    BEGIN
        IF ISNULL(@Filtro, '') = ''
        BEGIN
            SET @O_Msg = 'Filtro requerido.';
            SET @O_Num = -1;
            RETURN;
        END

        SELECT
            dv.Id_Detalle,
            dv.Id_Venta,
            v.Total AS Total_Venta_General,
            dv.Id_Producto,
            p.Nombre AS Producto,
            dv.Id_Bodega,
            dv.Cantidad,
            dv.Precio_Unitario_Al_Momento_Venta,
            dv.Subtotal,
            dv.Id_Estado,
            es.Estado,
            dv.Fecha_Creacion,
            dv.Fecha_Modificacion,
            dv.Id_Creador,
            dv.Id_Modificador
        FROM Tbl_Detalle_Venta dv
        JOIN Tbl_Ventas   v  ON dv.Id_Venta   = v.Id_Venta
        JOIN Tbl_Producto p  ON dv.Id_Producto = p.Id_Producto
        JOIN Cls_Estados  es ON dv.Id_Estado   = es.Id_Estado
        WHERE CAST(dv.Id_Detalle AS VARCHAR) = @Filtro
           OR CAST(dv.Id_Venta   AS VARCHAR) = @Filtro
           OR p.Nombre LIKE '%' + @Filtro + '%';

        SET @O_Msg = 'Consulta de detalle de venta filtrada.';
        SET @O_Num = 0;
    END

    ELSE
    BEGIN
        SET @O_Msg = 'Modo no reconocido.';
        SET @O_Num = -1;
    END
END
GO