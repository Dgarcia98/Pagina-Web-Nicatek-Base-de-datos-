CREATE OR ALTER PROC spClsMetodosPago
    @Mode VARCHAR(3) = NULL,
    @O_Msg VARCHAR(255) = NULL OUTPUT,
    @O_Num INT = NULL OUTPUT,
    @Id_Metodo_Pago INT = NULL,
    @Descripcion VARCHAR(50) = NULL, 
    @Id_Estado INT = NULL,          
    @Id_Creador INT = NULL,
    @Id_Modificador INT = NULL,
    @Activo BIT = NULL,
    @Filtro VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Mode = 'INS'
    BEGIN

        IF @Descripcion IS NULL OR @Id_Estado IS NULL OR @Id_Creador IS NULL
        BEGIN
            SET @O_Msg = 'Faltan campos obligatorios (Descripcion, Estado, Creador).';
            SET @O_Num = -1;
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM Cls_Metodos_Pago WHERE Descripcion = @Descripcion AND Activo = 1)
        BEGIN
            SET @O_Msg = 'Ya existe un método de pago con esa descripción.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;
                INSERT INTO Cls_Metodos_Pago (
                    Descripcion, 
                    Id_Estado,
                    Activo, 
                    Fecha_Creacion, 
                    Id_Creador, 
                    Id_Modificador,
                    Fecha_Modificacion
                )
                VALUES (
                    @Descripcion, 
                    @Id_Estado,
                    COALESCE(@Activo, 1), 
                    GETDATE(), 
                    @Id_Creador, 
                    @Id_Modificador,
                    GETDATE()
                );

                SET @O_Num = SCOPE_IDENTITY();
                SET @O_Msg = 'Método de pago registrado correctamente.';
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
        IF @Id_Metodo_Pago IS NULL
        BEGIN
            SET @O_Msg = 'El ID del método de pago es requerido.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;
                UPDATE Cls_Metodos_Pago
                SET Descripcion = COALESCE(@Descripcion, Descripcion),
                    Id_Estado = COALESCE(@Id_Estado, Id_Estado),
                    Activo = COALESCE(@Activo, Activo),
                    Fecha_Modificacion = GETDATE(),
                    Id_Modificador = COALESCE(@Id_Modificador, Id_Modificador)
                WHERE Id_Metodo_Pago = @Id_Metodo_Pago;

                SET @O_Num = @Id_Metodo_Pago;
                SET @O_Msg = 'Método de pago actualizado correctamente.';
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
        IF @Id_Metodo_Pago IS NULL OR @Id_Modificador IS NULL
        BEGIN
            SET @O_Msg = 'Se requiere el ID y el Modificador.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;
                UPDATE Cls_Metodos_Pago
                SET Activo = 0,
                    Fecha_Modificacion = GETDATE(),
                    Id_Modificador = @Id_Modificador
                WHERE Id_Metodo_Pago = @Id_Metodo_Pago;

                SET @O_Num = @Id_Metodo_Pago;
                SET @O_Msg = 'Método de pago eliminado correctamente.';
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
            Id_Metodo_Pago,
            Descripcion,
            Id_Estado,
            Activo,
            Fecha_Creacion,
            Fecha_Modificacion,
            Id_Creador,
            Id_Modificador
        FROM Cls_Metodos_Pago
        WHERE Activo = 1;

        SET @O_Msg = 'Listado exitoso.';
        SET @O_Num = 0;
    END

    ELSE IF @Mode = 'FIL'
    BEGIN
        SELECT 
            Id_Metodo_Pago,
            Descripcion,
            Id_Estado,
            Activo,
            Fecha_Creacion,
            Fecha_Modificacion,
            Id_Creador,
            Id_Modificador
        FROM Cls_Metodos_Pago
        WHERE Activo = 1 
          AND (Descripcion LIKE '%' + ISNULL(@Filtro, '') + '%' 
               OR CAST(Id_Metodo_Pago AS VARCHAR) = ISNULL(@Filtro, ''));

        SET @O_Msg = 'Búsqueda exitosa.';
        SET @O_Num = 0;
    END
END