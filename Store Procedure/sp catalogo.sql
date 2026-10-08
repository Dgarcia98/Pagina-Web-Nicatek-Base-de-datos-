CREATE OR ALTER PROC spClsCatalogos
    @Mode VARCHAR(3) = NULL,
    @O_Msg VARCHAR(255) = NULL OUTPUT,
    @O_Num INT = NULL OUTPUT,
    @Id_Catalogo INT = NULL,
    @Id_Tipo_Catalogo INT = NULL,
    @Catalogo VARCHAR(80) = NULL,
    @Id_Creador INT = NULL,
    @Id_Modificador INT = NULL,
    @Activo BIT = NULL,
    @Filtro VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Mode = 'INS'
    BEGIN
        IF @Id_Tipo_Catalogo IS NULL OR @Catalogo IS NULL OR @Id_Creador IS NULL OR @Id_Modificador IS NULL
        BEGIN
            SET @O_Msg = 'Faltan campos obligatorios.';
            SET @O_Num = -1;
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Cls_Tipo_Catalogos WHERE Id_Tipo_Catalogo = @Id_Tipo_Catalogo)
        BEGIN
            SET @O_Msg = 'El tipo de catálogo especificado no existe.';
            SET @O_Num = -1;
            RETURN;
        END

        IF EXISTS (
            SELECT 1 FROM Cls_Catalogos 
            WHERE Id_Tipo_Catalogo = @Id_Tipo_Catalogo AND Catalogo = @Catalogo AND Activo = 1
        )
        BEGIN
            SET @O_Msg = 'Ya existe ese catálogo activo para el tipo especificado.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            INSERT INTO Cls_Catalogos (
                Id_Tipo_Catalogo, Catalogo, Fecha_Creacion, Fecha_Modificacion,
                Activo, Id_Creador, Id_Modificador
            )
            VALUES (
                @Id_Tipo_Catalogo, @Catalogo, GETDATE(), GETDATE(),
                COALESCE(@Activo, 1), @Id_Creador, @Id_Modificador
            );

            SET @O_Num = SCOPE_IDENTITY();
            SET @O_Msg = 'Catálogo registrado correctamente.';
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
        IF @Id_Catalogo IS NULL
        BEGIN
            SET @O_Msg = 'Id_Catalogo requerido para actualizar.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            UPDATE Cls_Catalogos
            SET Id_Tipo_Catalogo = COALESCE(@Id_Tipo_Catalogo, Id_Tipo_Catalogo),
                Catalogo = COALESCE(@Catalogo, Catalogo),
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = COALESCE(@Id_Modificador, Id_Modificador),
                Activo = COALESCE(@Activo, Activo)
            WHERE Id_Catalogo = @Id_Catalogo;

            SET @O_Num = @Id_Catalogo;
            SET @O_Msg = 'Catálogo actualizado correctamente.';
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
        IF @Id_Catalogo IS NULL OR @Id_Modificador IS NULL
        BEGIN
            SET @O_Msg = 'Id_Catalogo e Id_Modificador requeridos para eliminar.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            UPDATE Cls_Catalogos
            SET Activo = 0,
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = @Id_Modificador
            WHERE Id_Catalogo = @Id_Catalogo;

            SET @O_Num = @Id_Catalogo;
            SET @O_Msg = 'Catálogo eliminado (inactivado) correctamente.';
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
            c.Id_Catalogo,
            c.Id_Tipo_Catalogo,
            tc.Tipo_Catalogo, 
            c.Catalogo,
            c.Activo,
            c.Fecha_Creacion,
            c.Fecha_Modificacion,
            c.Id_Creador,
            c.Id_Modificador
        FROM Cls_Catalogos c
        INNER JOIN Cls_Tipo_Catalogos tc ON c.Id_Tipo_Catalogo = tc.Id_Tipo_Catalogo
        WHERE c.Activo = 1;

        SET @O_Msg = 'Listado de catálogos.';
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
            c.Id_Catalogo,
            c.Id_Tipo_Catalogo,
            tc.Tipo_Catalogo,
            c.Catalogo,
            c.Activo,
            c.Fecha_Creacion,
            c.Fecha_Modificacion,
            c.Id_Creador,
            c.Id_Modificador
        FROM Cls_Catalogos c
        INNER JOIN Cls_Tipo_Catalogos tc ON c.Id_Tipo_Catalogo = tc.Id_Tipo_Catalogo
        WHERE (c.Catalogo LIKE '%' + @Filtro + '%'
            OR tc.Tipo_Catalogo LIKE '%' + @Filtro + '%'
            OR CAST(c.Id_Catalogo AS VARCHAR) = @Filtro)
            AND c.Activo = 1;

        SET @O_Msg = 'Consulta filtrada realizada.';
        SET @O_Num = 0;
    END

    ELSE
    BEGIN
        SET @O_Msg = 'Modo no reconocido.';
        SET @O_Num = -1;
    END
END
GO