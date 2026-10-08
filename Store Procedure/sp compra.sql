USE NicaTek;
GO

CREATE OR ALTER PROC sp_Tbl_Compra
    @Mode VARCHAR(3) = NULL,
    @O_Msg VARCHAR(255) = NULL OUTPUT,
    @O_Num INT = NULL OUTPUT,
    @Id_Compra INT = NULL,
    @Id_Proveedor INT = NULL,
    @Numero_Factura_Proveedor VARCHAR(50) = NULL,
    @Fecha_Compra DATE = NULL,
    @Total_Compra DECIMAL(12,2) = NULL,
    @Id_Estado INT = NULL,
    @Id_Creador INT = NULL,
    @Id_Modificador INT = NULL,
    @Filtro VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Mode = 'INS'
    BEGIN
        IF @Id_Proveedor IS NULL OR @Total_Compra IS NULL 
           OR @Id_Estado IS NULL OR @Id_Creador IS NULL OR @Id_Modificador IS NULL
        BEGIN
            SET @O_Msg = 'Faltan campos obligatorios.';
            SET @O_Num = -1;
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Tbl_Proveedor WHERE Id_Proveedor = @Id_Proveedor)
        BEGIN
            SET @O_Msg = 'El proveedor especificado no existe.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;
            INSERT INTO Tbl_Compra (
                Id_Proveedor, Numero_Factura_Proveedor, Fecha_Compra,
                Total_Compra, Id_Estado, 
                Fecha_Creacion, Fecha_Modificacion, Id_Creador, Id_Modificador
            )
            VALUES (
                @Id_Proveedor, @Numero_Factura_Proveedor, COALESCE(@Fecha_Compra, GETDATE()),
                @Total_Compra, @Id_Estado,
                GETDATE(), GETDATE(), @Id_Creador, @Id_Modificador
            );
            SET @O_Num = CAST(SCOPE_IDENTITY() AS INT);
            SET @O_Msg = 'Compra registrada correctamente.';
            COMMIT;
        END TRY
        BEGIN CATCH
            ROLLBACK;
            SET @O_Msg = ERROR_MESSAGE();
            SET @O_Num = ERROR_NUMBER();
        END CATCH
    END

    ELSE IF @Mode = 'UPD'
    BEGIN
        IF @Id_Compra IS NULL
        BEGIN
            SET @O_Msg = 'Id_Compra requerido para actualizar.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;
            UPDATE Tbl_Compra
            SET Id_Proveedor = COALESCE(@Id_Proveedor, Id_Proveedor),
                Numero_Factura_Proveedor = COALESCE(@Numero_Factura_Proveedor, Numero_Factura_Proveedor),
                Fecha_Compra = COALESCE(@Fecha_Compra, Fecha_Compra),
                Total_Compra = COALESCE(@Total_Compra, Total_Compra),
                Id_Estado = COALESCE(@Id_Estado, Id_Estado),
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = COALESCE(@Id_Modificador, Id_Modificador)
            WHERE Id_Compra = @Id_Compra;
            SET @O_Num = @Id_Compra;
            SET @O_Msg = 'Compra actualizada correctamente.';
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
        IF @Id_Compra IS NULL OR @Id_Modificador IS NULL
        BEGIN
            SET @O_Msg = 'Id_Compra e Id_Modificador requeridos.';
            SET @O_Num = -1;
            RETURN;
        END

        DECLARE @EstadoActual INT;
        
        SELECT @EstadoActual = Id_Estado FROM Tbl_Compra WHERE Id_Compra = @Id_Compra;
        
        IF @EstadoActual = 3 
        BEGIN
            SET @O_Msg = 'La compra ya se encuentra anulada.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            DECLARE @Cur_Id_Producto INT;
            DECLARE @Cur_Cantidad INT;
            DECLARE @Cur_Id_Bodega INT;
            DECLARE @StockAnterior INT;
            DECLARE @StockActual INT;

            DECLARE cursor_detalle_compra CURSOR FOR 
            SELECT Id_Producto, Cantidad 
            FROM Tbl_Detalle_Compra 
            WHERE Id_Compra = @Id_Compra; 

            OPEN cursor_detalle_compra;
            FETCH NEXT FROM cursor_detalle_compra INTO @Cur_Id_Producto, @Cur_Cantidad;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                SELECT TOP 1 @Cur_Id_Bodega = Id_Bodega, @StockAnterior = Cantidad 
                FROM Tbl_Bodega 
                WHERE Id_Producto = @Cur_Id_Producto;

                IF @Cur_Id_Bodega IS NOT NULL
                BEGIN
                    SET @StockActual = @StockAnterior - @Cur_Cantidad;

                    -- Solo insertamos en el Kardex. El Trigger detectará este INSERT 
                    -- y hará el UPDATE en Tbl_Bodega automáticamente basándose en la Operación.
                    INSERT INTO Tbl_Movimientos_Inventario (
                        Id_Producto, Id_Bodega, Id_Tipo_Movimiento, Cantidad, 
                        Stock_Anterior, Stock_Actual, Costo_Unitario, 
                        Referencia, Observaciones, Fecha_Movimiento, Id_Usuario_Responsable
                    )
                    VALUES (
                        @Cur_Id_Producto, @Cur_Id_Bodega, 4, @Cur_Cantidad, 
                        @StockAnterior, @StockActual, 0, 
                        'Anulación Compra #' + CAST(@Id_Compra AS VARCHAR), 'Stock retirado', GETDATE(), @Id_Modificador
                    );
                END
                FETCH NEXT FROM cursor_detalle_compra INTO @Cur_Id_Producto, @Cur_Cantidad;
            END

            CLOSE cursor_detalle_compra;
            DEALLOCATE cursor_detalle_compra;

            UPDATE Tbl_Compra
            SET Id_Estado = 3, 
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = @Id_Modificador
            WHERE Id_Compra = @Id_Compra;

            SET @O_Num = @Id_Compra;
            SET @O_Msg = 'Compra anulada correctamente.';
            
            COMMIT TRAN;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRAN;
            IF CURSOR_STATUS('global', 'cursor_detalle_compra') >= -1
            BEGIN
                CLOSE cursor_detalle_compra;
                DEALLOCATE cursor_detalle_compra;
            END
            SET @O_Msg = ERROR_MESSAGE();
            SET @O_Num = 0; 
        END CATCH
    END

    ELSE IF @Mode = 'LST'
    BEGIN
        SELECT 
            c.Id_Compra,
            c.Id_Proveedor,
            LTRIM(RTRIM(ISNULL(dp.Primer_Nombre, '') + ' ' + ISNULL(dp.Primer_Apellido, ''))) AS Proveedor,
            c.Numero_Factura_Proveedor,
            c.Fecha_Compra,
            c.Total_Compra,
            c.Id_Estado,
            es.Estado,
            c.Fecha_Creacion,
            c.Fecha_Modificacion,
            c.Id_Creador,
            c.Id_Modificador
        FROM Tbl_Compra c
        JOIN Tbl_Proveedor pr ON c.Id_Proveedor = pr.Id_Proveedor
        JOIN Tbl_Datos_Personales dp ON pr.Id_Persona = dp.Id_Persona
        JOIN Cls_Estados es ON c.Id_Estado = es.Id_Estado;
        SET @O_Msg = 'Listado de compras.';
        SET @O_Num = 0;
    END

    ELSE IF @Mode = 'FIL'
    BEGIN
        SELECT 
            c.Id_Compra,
            c.Id_Proveedor,
            LTRIM(RTRIM(ISNULL(dp.Primer_Nombre, '') + ' ' + ISNULL(dp.Primer_Apellido, ''))) AS Proveedor,
            c.Numero_Factura_Proveedor,
            c.Fecha_Compra,
            c.Total_Compra,
            c.Id_Estado,
            es.Estado,
            c.Fecha_Creacion,
            c.Fecha_Modificacion,
            c.Id_Creador,
            c.Id_Modificador
        FROM Tbl_Compra c
        JOIN Tbl_Proveedor pr ON c.Id_Proveedor = pr.Id_Proveedor
        JOIN Tbl_Datos_Personales dp ON pr.Id_Persona = dp.Id_Persona
        JOIN Cls_Estados es ON c.Id_Estado = es.Id_Estado
        WHERE CAST(c.Id_Compra AS VARCHAR) = @Filtro
           OR dp.Primer_Nombre LIKE '%' + @Filtro + '%'
           OR dp.Primer_Apellido LIKE '%' + @Filtro + '%'
           OR c.Numero_Factura_Proveedor LIKE '%' + @Filtro + '%'
           OR es.Estado LIKE '%' + @Filtro + '%';
        SET @O_Msg = 'Consulta de compras filtrada.';
        SET @O_Num = 0;
    END
END
GO