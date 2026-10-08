USE NicaTek;
GO

CREATE OR ALTER PROC sp_Tbl_Detalle_Compra
    @Mode VARCHAR(3) = NULL,
    @O_Msg VARCHAR(255) = NULL OUTPUT,
    @O_Num INT = NULL OUTPUT,
    @Id_Detalle_Compra INT = NULL,
    @Id_Compra INT = NULL,
    @Id_Bodega INT = NULL,          --  NUEVO: bodega destino seleccionada
    @Id_Producto INT = NULL,
    @Cantidad INT = NULL,
    @Precio_Unitario_Compra DECIMAL(12,2) = NULL,
    @Subtotal_Compra DECIMAL(12,2) = NULL,
    @Id_Creador INT = NULL,
    @Id_Modificador INT = NULL,
    @Filtro VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Mode = 'INS'
    BEGIN
        IF @Id_Compra IS NULL OR @Id_Producto IS NULL OR @Cantidad IS NULL
           OR @Precio_Unitario_Compra IS NULL 
           OR @Id_Creador IS NULL OR @Id_Modificador IS NULL
        BEGIN
            SET @O_Msg = 'Faltan datos obligatorios.';
            SET @O_Num = -1;
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Tbl_Compra WHERE Id_Compra = @Id_Compra)
        BEGIN
            SET @O_Msg = 'El ID de Compra no existe.';
            SET @O_Num = -1;
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Tbl_Producto WHERE Id_Producto = @Id_Producto)
        BEGIN
            SET @O_Msg = 'El ID de Producto no existe.';
            SET @O_Num = -1;
            RETURN;
        END

        IF @Subtotal_Compra IS NULL
        BEGIN
            SET @Subtotal_Compra = @Cantidad * @Precio_Unitario_Compra;
        END

        DECLARE @Stock_Anterior INT = 0;
        DECLARE @Stock_Actual INT = 0;
        DECLARE @Id_Tipo_Movimiento INT;

        SELECT TOP 1 @Id_Tipo_Movimiento = Id_Tipo_Movimiento 
        FROM Cls_Tipo_Movimiento 
        WHERE Descripcion = 'Compra a Proveedor';

        -- Si viene Id_Bodega del frontend, usarlo directamente
        -- Si no viene, buscar por Id_Producto como fallback
        IF @Id_Bodega IS NULL
        BEGIN
            SELECT @Id_Bodega = Id_Bodega, @Stock_Anterior = Cantidad 
            FROM Tbl_Bodega 
            WHERE Id_Producto = @Id_Producto AND Id_Estado = 1;
        END
        ELSE
        BEGIN
            SELECT @Stock_Anterior = Cantidad 
            FROM Tbl_Bodega 
            WHERE Id_Bodega = @Id_Bodega;
        END

        BEGIN TRY
            BEGIN TRAN;

            INSERT INTO Tbl_Detalle_Compra (
                Id_Compra, Id_Producto, Cantidad,
                Precio_Unitario_Compra, Subtotal_Compra,
                Fecha_Creacion, Fecha_Modificacion,
                Id_Creador, Id_Modificador
            )
            VALUES (
                @Id_Compra, @Id_Producto, @Cantidad,
                @Precio_Unitario_Compra, @Subtotal_Compra,
                GETDATE(), GETDATE(), @Id_Creador, @Id_Modificador
            );

            SET @O_Num = SCOPE_IDENTITY();

            -- Si no existe bodega, crearla
            IF @Id_Bodega IS NULL
            BEGIN
                INSERT INTO Tbl_Bodega (Id_Producto, Cantidad, Id_Estado, Id_Creador, Id_Modificador)
                VALUES (@Id_Producto, 0, 1, @Id_Creador, @Id_Modificador);
                
                SET @Id_Bodega = SCOPE_IDENTITY();
                SET @Stock_Anterior = 0;
            END

            SET @Stock_Actual = ISNULL(@Stock_Anterior, 0) + @Cantidad;

            -- Registrar movimiento — el trigger actualizará Tbl_Bodega automáticamente
            INSERT INTO Tbl_Movimientos_Inventario (
                Id_Producto, Id_Bodega, Id_Tipo_Movimiento, Cantidad,
                Stock_Anterior, Stock_Actual, Costo_Unitario,
                Referencia, Observaciones, Id_Usuario_Responsable
            )
            VALUES (
                @Id_Producto, @Id_Bodega, @Id_Tipo_Movimiento, @Cantidad,
                @Stock_Anterior, @Stock_Actual, @Precio_Unitario_Compra,
                CAST(@Id_Compra AS VARCHAR), 'Entrada por compra', @Id_Creador
            );

            -- Actualizar precio de compra en producto
            UPDATE Tbl_Producto
            SET Precio_Compra = @Precio_Unitario_Compra,
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = @Id_Modificador
            WHERE Id_Producto = @Id_Producto;

            SET @O_Msg = 'Detalle de compra registrado y stock actualizado.';
            COMMIT;
        END TRY
        BEGIN CATCH
            ROLLBACK;
            SET @O_Msg = ERROR_MESSAGE();
            SET @O_Num = ERROR_NUMBER();
            THROW;
        END CATCH
    END

    ELSE IF @Mode = 'UPD'
    BEGIN
        IF @Id_Detalle_Compra IS NULL
        BEGIN
            SET @O_Msg = 'Id_Detalle_Compra requerido.';
            SET @O_Num = -1;
            RETURN;
        END

        DECLARE @NuevaCantidad INT;
        DECLARE @NuevoPrecio DECIMAL(12,2);
        
        SELECT @NuevaCantidad = COALESCE(@Cantidad, Cantidad), 
               @NuevoPrecio = COALESCE(@Precio_Unitario_Compra, Precio_Unitario_Compra)
        FROM Tbl_Detalle_Compra WHERE Id_Detalle_Compra = @Id_Detalle_Compra;

        IF @Subtotal_Compra IS NULL
        BEGIN
            SET @Subtotal_Compra = @NuevaCantidad * @NuevoPrecio;
        END

        BEGIN TRY
            BEGIN TRAN;

            UPDATE Tbl_Detalle_Compra
            SET Cantidad = COALESCE(@Cantidad, Cantidad),
                Precio_Unitario_Compra = COALESCE(@Precio_Unitario_Compra, Precio_Unitario_Compra),
                Subtotal_Compra = @Subtotal_Compra,
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = COALESCE(@Id_Modificador, Id_Modificador)
            WHERE Id_Detalle_Compra = @Id_Detalle_Compra;

            SET @O_Num = @Id_Detalle_Compra;
            SET @O_Msg = 'Detalle actualizado correctamente.';
            COMMIT;
        END TRY
        BEGIN CATCH
            ROLLBACK;
            SET @O_Msg = ERROR_MESSAGE();
            SET @O_Num = ERROR_NUMBER();
        END CATCH
    END

    ELSE IF @Mode = 'DEL'
    BEGIN
        IF @Id_Detalle_Compra IS NULL
        BEGIN
            SET @O_Msg = 'Id_Detalle_Compra requerido.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            DELETE FROM Tbl_Detalle_Compra
            WHERE Id_Detalle_Compra = @Id_Detalle_Compra;

            SET @O_Num = @Id_Detalle_Compra;
            SET @O_Msg = 'Detalle eliminado correctamente.';
            COMMIT;
        END TRY
        BEGIN CATCH
            ROLLBACK;
            SET @O_Msg = ERROR_MESSAGE();
            SET @O_Num = ERROR_NUMBER();
        END CATCH
    END

    ELSE IF @Mode = 'LST'
    BEGIN
        SELECT 
            dc.Id_Detalle_Compra,
            dc.Id_Compra,
            c.Total_Compra,
            dc.Id_Producto,
            p.Nombre AS Producto,
            dc.Cantidad,
            dc.Precio_Unitario_Compra,
            dc.Subtotal_Compra,
            dc.Fecha_Creacion,
            dc.Fecha_Modificacion,
            dc.Id_Creador,
            dc.Id_Modificador
        FROM Tbl_Detalle_Compra dc
        JOIN Tbl_Compra c ON dc.Id_Compra = c.Id_Compra
        JOIN Tbl_Producto p ON dc.Id_Producto = p.Id_Producto;

        SET @O_Msg = 'Listado de detalle de compras.';
        SET @O_Num = 0;
    END

    ELSE IF @Mode = 'FIL'
    BEGIN
        IF ISNULL(@Filtro, '') = ''
        BEGIN
            SET @O_Msg = 'Filtro requerido.';
            SET @O_Num = -1;
        END
        ELSE
        BEGIN
            SELECT 
                dc.Id_Detalle_Compra,
                dc.Id_Compra,
                c.Total_Compra,
                dc.Id_Producto,
                p.Nombre AS Producto,
                dc.Cantidad,
                dc.Precio_Unitario_Compra,
                dc.Subtotal_Compra,
                dc.Fecha_Creacion,
                dc.Fecha_Modificacion,
                dc.Id_Creador,
                dc.Id_Modificador
            FROM Tbl_Detalle_Compra dc
            JOIN Tbl_Compra c ON dc.Id_Compra = c.Id_Compra
            JOIN Tbl_Producto p ON dc.Id_Producto = p.Id_Producto
            WHERE CAST(dc.Id_Detalle_Compra AS VARCHAR) = @Filtro
               OR CAST(dc.Id_Compra AS VARCHAR) = @Filtro
               OR p.Nombre LIKE '%' + @Filtro + '%';

            IF @@ROWCOUNT > 0
            BEGIN
                SET @O_Msg = 'Consulta de detalle de compra filtrada.';
                SET @O_Num = 0;
            END
            ELSE
            BEGIN
                SET @O_Msg = 'No se encontraron detalles con ese filtro.';
                SET @O_Num = 0;
            END
        END
    END

    ELSE
    BEGIN
        SET @O_Msg = 'Modo no reconocido.';
        SET @O_Num = -1;
    END
END
GO