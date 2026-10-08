USE NicaTek;
GO

CREATE OR ALTER PROC sp_Cls_Tipo_Catalogos
    @Mode VARCHAR(3) = NULL,
    @O_Msg VARCHAR(255) = NULL OUTPUT,
    @O_Num INT = NULL OUTPUT,
    @Id_Tipo_Catalogo INT = NULL,
    @Tipo_Catalogo VARCHAR(80) = NULL,
    @Id_Creador INT = NULL,
    @Id_Modificador INT = NULL,
    @Activo BIT = NULL,
    @Filtro VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Mode = 'INS'
    BEGIN
        IF @Tipo_Catalogo IS NULL OR @Id_Creador IS NULL OR @Id_Modificador IS NULL OR @Activo IS NULL
        BEGIN
            SET @O_Msg = 'Faltan campos obligatorios.';
            SET @O_Num = -1;
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM Cls_Tipo_Catalogos WHERE Tipo_Catalogo = @Tipo_Catalogo)
        BEGIN
            SET @O_Msg = 'Ya existe un tipo de catálogo con ese nombre.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            INSERT INTO Cls_Tipo_Catalogos (
                Tipo_Catalogo, Fecha_Creacion, Fecha_Modificacion,
                Id_Creador, Id_Modificador, Activo
            )
            VALUES (
                @Tipo_Catalogo, GETDATE(), GETDATE(),
                @Id_Creador, @Id_Modificador, @Activo
            );

            SET @O_Num = SCOPE_IDENTITY();
            SET @O_Msg = 'Tipo de catálogo registrado correctamente.';
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
        IF @Id_Tipo_Catalogo IS NULL
        BEGIN
            SET @O_Msg = 'Id_Tipo_Catalogo requerido para actualizar.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            UPDATE Cls_Tipo_Catalogos
            SET Tipo_Catalogo = COALESCE(@Tipo_Catalogo, Tipo_Catalogo),
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = COALESCE(@Id_Modificador, Id_Modificador),
                Activo = COALESCE(@Activo, Activo)
            WHERE Id_Tipo_Catalogo = @Id_Tipo_Catalogo;

            SET @O_Num = @Id_Tipo_Catalogo;
            SET @O_Msg = 'Tipo de catálogo actualizado correctamente.';
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
        IF @Id_Tipo_Catalogo IS NULL OR @Id_Modificador IS NULL
        BEGIN
            SET @O_Msg = 'Id_Tipo_Catalogo e Id_Modificador requeridos.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            UPDATE Cls_Tipo_Catalogos
            SET Activo = 0,
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = @Id_Modificador
            WHERE Id_Tipo_Catalogo = @Id_Tipo_Catalogo;

            SET @O_Num = @Id_Tipo_Catalogo;
            SET @O_Msg = 'Tipo de catálogo inactivado correctamente.';
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
            Id_Tipo_Catalogo,
            Tipo_Catalogo,
            Fecha_Creacion,
            Fecha_Modificacion,
            Id_Creador,
            Id_Modificador,
            Activo,
            CASE WHEN Activo = 1 THEN 'Sí' ELSE 'No' END AS EstadoActivo
        FROM Cls_Tipo_Catalogos;

        SET @O_Msg = 'Listado de tipos de catálogo.';
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
                Id_Tipo_Catalogo,
                Tipo_Catalogo,
                Fecha_Creacion,
                Fecha_Modificacion,
                Id_Creador,
                Id_Modificador,
                Activo,
                CASE WHEN Activo = 1 THEN 'Sí' ELSE 'No' END AS EstadoActivo
            FROM Cls_Tipo_Catalogos
            WHERE Tipo_Catalogo LIKE '%' + @Filtro + '%'
               OR CAST(Id_Tipo_Catalogo AS VARCHAR) = @Filtro;

            IF @@ROWCOUNT > 0
            BEGIN
                SET @O_Msg = 'Consulta con filtro realizada.';
                SET @O_Num = 0;
            END
            ELSE
            BEGIN
                SET @O_Msg = 'No se encontraron tipos de catálogo con ese filtro.';
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