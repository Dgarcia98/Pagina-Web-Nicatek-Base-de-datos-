USE NicaTek;
GO

IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_NAME = 'Tbl_Detalle_Venta' AND COLUMN_NAME = 'Id_Bodega'
)
BEGIN
    ALTER TABLE Tbl_Detalle_Venta ADD Id_Bodega INT NULL;
    ALTER TABLE Tbl_Detalle_Venta 
        ADD CONSTRAINT FK_Detalle_Venta_Bodega 
        FOREIGN KEY (Id_Bodega) REFERENCES Tbl_Bodega(Id_Bodega);
END
GO

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
        IF @Id_Cliente IS NULL OR @Total IS NULL OR @Id_Estado IS NULL OR @Id_Creador IS NULL
        BEGIN
            SET @O_Msg = 'Faltan datos para registrar la venta.';
            SET @O_Num = -1;
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Tbl_Cliente WHERE Id_Cliente = @Id_Cliente)
        BEGIN
            SET @O_Msg = 'El cliente especificado no existe.';
            SET @O_Num = -1;
            RETURN;
        END

        IF @Id_Metodo_Pago IS NOT NULL AND NOT EXISTS (SELECT 1 FROM Cls_Metodos_Pago WHERE Id_Metodo_Pago = @Id_Metodo_Pago)
        BEGIN
            SET @O_Msg = 'El método de pago especificado no existe.';
            SET @O_Num = -1;
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Cls_Estados WHERE Id_Estado = @Id_Estado)
        BEGIN
            SET @O_Msg = 'El estado especificado no existe.';
            SET @O_Num = -1;
            RETURN;
        END

        DECLARE @EmpleadoCalculado INT;
        SELECT @EmpleadoCalculado = e.Id_Empleado
        FROM Tbl_Usuarios u
        JOIN Tbl_Datos_Personales dp ON u.Id_Persona = dp.Id_Persona
        JOIN Tbl_Empleado e ON dp.Id_Persona = e.Id_Persona
        WHERE u.Id_Usuario = @Id_Creador;

        SET @Id_Empleado = @EmpleadoCalculado;

        BEGIN TRY
            BEGIN TRAN;

            INSERT INTO Tbl_Ventas (
                Fecha, Id_Cliente, Id_Empleado, Id_Metodo_Pago, Total,
                Id_Estado, Fecha_Creacion, Fecha_Modificacion,
                Id_Creador, Id_Modificador
            )
            VALUES (
                COALESCE(@Fecha, GETDATE()), @Id_Cliente, @Id_Empleado, @Id_Metodo_Pago, @Total,
                @Id_Estado, GETDATE(), GETDATE(), @Id_Creador,
                ISNULL(@Id_Modificador, @Id_Creador)
            );

            SET @O_Num = SCOPE_IDENTITY();
            SET @O_Msg = 'Venta registrada correctamente.';
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
        IF @Id_Venta IS NULL
        BEGIN
            SET @O_Msg = 'Id_Venta requerido.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            UPDATE Tbl_Ventas
            SET Fecha              = COALESCE(@Fecha,          Fecha),
                Id_Cliente         = COALESCE(@Id_Cliente,     Id_Cliente),
                Id_Empleado        = COALESCE(@Id_Empleado,    Id_Empleado),
                Id_Metodo_Pago     = COALESCE(@Id_Metodo_Pago, Id_Metodo_Pago),
                Total              = COALESCE(@Total,          Total),
                Id_Estado          = COALESCE(@Id_Estado,      Id_Estado),
                Fecha_Modificacion = GETDATE(),
                Id_Modificador     = COALESCE(@Id_Modificador, Id_Modificador)
            WHERE Id_Venta = @Id_Venta;

            SET @O_Num = @Id_Venta;
            SET @O_Msg = 'Venta actualizada correctamente.';
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
        IF @Id_Venta IS NULL OR @Id_Modificador IS NULL
        BEGIN
            SET @O_Msg = 'Id_Venta e Id_Modificador requeridos.';
            SET @O_Num = -1;
            RETURN;
        END

        DECLARE @EstadoActual INT;
        SELECT @EstadoActual = Id_Estado FROM Tbl_Ventas WHERE Id_Venta = @Id_Venta;

        IF @EstadoActual = 3
        BEGIN
            SET @O_Msg = 'La venta ya se encuentra anulada.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            DECLARE @Cur_Id_Producto INT;
            DECLARE @Cur_Id_Bodega   INT;
            DECLARE @Cur_Cantidad    INT;
            DECLARE @StockAnterior   INT;
            DECLARE @StockActual     INT;

            DECLARE cursor_detalle CURSOR FOR
                SELECT Id_Producto, Id_Bodega, Cantidad
                FROM Tbl_Detalle_Venta
                WHERE Id_Venta = @Id_Venta AND Id_Estado != 3;

            OPEN cursor_detalle;
            FETCH NEXT FROM cursor_detalle INTO @Cur_Id_Producto, @Cur_Id_Bodega, @Cur_Cantidad;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                SELECT @StockAnterior = Cantidad
                FROM Tbl_Bodega_Producto
                WHERE Id_Bodega   = @Cur_Id_Bodega
                  AND Id_Producto = @Cur_Id_Producto;

                IF @Cur_Id_Bodega IS NOT NULL
                BEGIN
                    SET @StockActual = ISNULL(@StockAnterior, 0) + @Cur_Cantidad;

                    UPDATE Tbl_Bodega_Producto
                    SET Cantidad           = @StockActual,
                        Fecha_Modificacion = GETDATE(),
                        Id_Modificador     = @Id_Modificador
                    WHERE Id_Bodega   = @Cur_Id_Bodega
                      AND Id_Producto = @Cur_Id_Producto;

                    INSERT INTO Tbl_Movimientos_Inventario (
                        Id_Producto, Id_Bodega, Id_Tipo_Movimiento, Cantidad,
                        Stock_Anterior, Stock_Actual, Costo_Unitario,
                        Referencia, Observaciones, Fecha_Movimiento, Id_Usuario_Responsable
                    )
                    VALUES (
                        @Cur_Id_Producto, @Cur_Id_Bodega, 5, @Cur_Cantidad,
                        ISNULL(@StockAnterior, 0), @StockActual, 0,
                        'Anulación Venta #' + CAST(@Id_Venta AS VARCHAR),
                        'Stock devuelto por anulación', GETDATE(), @Id_Modificador
                    );
                END

                FETCH NEXT FROM cursor_detalle INTO @Cur_Id_Producto, @Cur_Id_Bodega, @Cur_Cantidad;
            END

            CLOSE cursor_detalle;
            DEALLOCATE cursor_detalle;

            UPDATE Tbl_Detalle_Venta
            SET Id_Estado          = 3,
                Fecha_Modificacion = GETDATE(),
                Id_Modificador     = @Id_Modificador
            WHERE Id_Venta = @Id_Venta;

            UPDATE Tbl_Ventas
            SET Id_Estado          = 3,
                Fecha_Modificacion = GETDATE(),
                Id_Modificador     = @Id_Modificador
            WHERE Id_Venta = @Id_Venta;

            SET @O_Num = @Id_Venta;
            SET @O_Msg = 'Venta anulada correctamente. El inventario ha sido restaurado.';
            COMMIT TRAN;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRAN;
            IF CURSOR_STATUS('global', 'cursor_detalle') >= -1
            BEGIN
                CLOSE cursor_detalle;
                DEALLOCATE cursor_detalle;
            END
            SET @O_Msg = ERROR_MESSAGE();
            SET @O_Num = -1;
        END CATCH
    END

    ELSE IF @Mode = 'LST'
    BEGIN
        SELECT
            v.Id_Venta,
            v.Numero_Factura,
            v.Fecha,
            v.Id_Cliente,
            LTRIM(RTRIM(ISNULL(dc.Primer_Nombre, '') + ' ' + ISNULL(dc.Primer_Apellido, ''))) AS Cliente,
            v.Id_Empleado,
            ISNULL(
                NULLIF(LTRIM(RTRIM(ISNULL(de.Primer_Nombre, '') + ' ' + ISNULL(de.Primer_Apellido, ''))), ''),
                'Administrador del Sistema'
            ) AS Empleado,
            v.Id_Metodo_Pago,
            mp.Descripcion AS Metodo_Pago,
            v.Total,
            v.Id_Estado,
            es.Estado,
            v.Fecha_Creacion,
            v.Fecha_Modificacion,
            v.Id_Creador,
            v.Id_Modificador
        FROM Tbl_Ventas v
        JOIN Tbl_Cliente c                ON v.Id_Cliente     = c.Id_Cliente
        JOIN Tbl_Datos_Personales dc      ON c.Id_Persona     = dc.Id_Persona
        LEFT JOIN Tbl_Empleado e          ON v.Id_Empleado    = e.Id_Empleado
        LEFT JOIN Tbl_Datos_Personales de ON e.Id_Persona     = de.Id_Persona
        LEFT JOIN Cls_Metodos_Pago mp     ON v.Id_Metodo_Pago = mp.Id_Metodo_Pago
        JOIN Cls_Estados es               ON v.Id_Estado      = es.Id_Estado;

        SET @O_Msg = 'Listado de ventas.';
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
            v.Id_Venta,
            v.Numero_Factura,
            v.Fecha,
            v.Id_Cliente,
            LTRIM(RTRIM(ISNULL(dc.Primer_Nombre, '') + ' ' + ISNULL(dc.Primer_Apellido, ''))) AS Cliente,
            v.Id_Empleado,
            ISNULL(
                NULLIF(LTRIM(RTRIM(ISNULL(de.Primer_Nombre, '') + ' ' + ISNULL(de.Primer_Apellido, ''))), ''),
                'Administrador del Sistema'
            ) AS Empleado,
            v.Id_Metodo_Pago,
            mp.Descripcion AS Metodo_Pago,
            v.Total,
            v.Id_Estado,
            es.Estado,
            v.Fecha_Creacion,
            v.Fecha_Modificacion,
            v.Id_Creador,
            v.Id_Modificador
        FROM Tbl_Ventas v
        JOIN Tbl_Cliente c                ON v.Id_Cliente     = c.Id_Cliente
        JOIN Tbl_Datos_Personales dc      ON c.Id_Persona     = dc.Id_Persona
        LEFT JOIN Tbl_Empleado e          ON v.Id_Empleado    = e.Id_Empleado
        LEFT JOIN Tbl_Datos_Personales de ON e.Id_Persona     = de.Id_Persona
        LEFT JOIN Cls_Metodos_Pago mp     ON v.Id_Metodo_Pago = mp.Id_Metodo_Pago
        JOIN Cls_Estados es               ON v.Id_Estado      = es.Id_Estado
        WHERE CAST(v.Id_Venta AS VARCHAR) = @Filtro
           OR v.Numero_Factura            LIKE '%' + @Filtro + '%'
           OR dc.Primer_Nombre            LIKE '%' + @Filtro + '%'
           OR dc.Primer_Apellido          LIKE '%' + @Filtro + '%'
           OR es.Estado                   LIKE '%' + @Filtro + '%';

        SET @O_Msg = 'Consulta de ventas filtrada.';
        SET @O_Num = 0;
    END

    ELSE
    BEGIN
        SET @O_Msg = 'Modo no reconocido.';
        SET @O_Num = -1;
    END
END
GO