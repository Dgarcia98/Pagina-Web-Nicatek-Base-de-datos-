USE NicaTek;
GO

CREATE OR ALTER PROC spClsEstados
    @Mode VARCHAR(3) = NULL,
    @O_Msg VARCHAR(255) = NULL OUTPUT,
    @O_Num INT = NULL OUTPUT,
    @Id_Estado INT = NULL,
    @Estado VARCHAR(80) = NULL,
    @Id_Creador INT = NULL,
    @Id_Modificador INT = NULL,
    @Activo BIT = NULL,
    @Filtro VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- INSERTAR
    IF @Mode = 'INS'
    BEGIN
    
        IF @Estado IS NULL OR @Id_Creador IS NULL OR @Id_Modificador IS NULL OR @Activo IS NULL
        BEGIN
            SET @O_Msg = 'Faltan campos obligatorios.';
            SET @O_Num = -1;
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM Cls_Estados WHERE Estado = @Estado)
        BEGIN
            SET @O_Msg = 'Ya existe un estado con ese nombre.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            INSERT INTO Cls_Estados (
                Estado, Fecha_Creacion, Fecha_Modificacion,
                Id_Creador, Id_Modificador, Activo
            )
            VALUES (
                @Estado, GETDATE(), GETDATE(),
                @Id_Creador, @Id_Modificador, @Activo
            );

            SET @O_Num = SCOPE_IDENTITY();
            SET @O_Msg = 'Estado registrado correctamente.';
            COMMIT;
        END TRY
        BEGIN CATCH
            ROLLBACK;
            SET @O_Msg = ERROR_MESSAGE();
            SET @O_Num = ERROR_NUMBER();
        END CATCH
    END

    -- ACTUALIZAR
    ELSE IF @Mode = 'UPD'
    BEGIN
        IF @Id_Estado IS NULL
        BEGIN
            SET @O_Msg = 'Id_Estado requerido para actualizar.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            UPDATE Cls_Estados
            SET Estado = COALESCE(@Estado, Estado),
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = COALESCE(@Id_Modificador, Id_Modificador),
                Activo = COALESCE(@Activo, Activo)
            WHERE Id_Estado = @Id_Estado;

            SET @O_Num = @Id_Estado;
            SET @O_Msg = 'Estado actualizado correctamente.';
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
        IF @Id_Estado IS NULL OR @Id_Modificador IS NULL
        BEGIN
            SET @O_Msg = 'Id_Estado e Id_Modificador requeridos para eliminar.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;
           UPDATE Cls_Estados
            SET Activo = 0,
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = @Id_Modificador
            WHERE Id_Estado = @Id_Estado;

            SET @O_Num = @Id_Estado;
            SET @O_Msg = 'Estado inactivado correctamente.';
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
            Id_Estado,
            Estado,
            Activo,
            Fecha_Creacion,
            Fecha_Modificacion,
            Id_Creador,
            Id_Modificador
        FROM Cls_Estados
        ORDER BY Estado ASC;

        SET @O_Msg = 'Listado de estados.';
        SET @O_Num = 0;
    END
    ELSE IF @Mode = 'CMB'
    BEGIN
        SELECT 
            Id_Estado,
            Estado
        FROM Cls_Estados
        WHERE Activo = 1
        ORDER BY Estado ASC;

        SET @O_Msg = 'Listado de estados activos.';
        SET @O_Num = 0;
    END

    ELSE IF @Mode = 'FIL'
    BEGIN
        IF ISNULL(@Filtro, '') = ''
        BEGIN
            SET @O_Msg = 'Debe proporcionar un filtro válido.';
            SET @O_Num = -1;
            RETURN;
        END

        SELECT 
            Id_Estado,
            Estado,
            Activo,
            Fecha_Creacion,
            Fecha_Modificacion,
            Id_Creador,
            Id_Modificador
        FROM Cls_Estados
        WHERE Estado LIKE '%' + @Filtro + '%'
           OR CAST(Id_Estado AS VARCHAR) = @Filtro
        ORDER BY Estado ASC;

        SET @O_Msg = 'Filtro aplicado correctamente.';
        SET @O_Num = 0;
    END

    ELSE
    BEGIN
        SET @O_Msg = 'Modo no reconocido.';
        SET @O_Num = -1;
    END
END
GO