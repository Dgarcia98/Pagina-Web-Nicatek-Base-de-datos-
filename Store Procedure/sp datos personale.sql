USE NicaTek;
GO

CREATE OR ALTER PROC sp_Tbl_Datos_Personales
    @Mode VARCHAR(3) = NULL,
    @O_Msg VARCHAR(255) = NULL OUTPUT,
    @O_Num INT = NULL OUTPUT,
    @Id_Persona INT = NULL,
    @Primer_Nombre VARCHAR(80) = NULL,
    @Segundo_Nombre VARCHAR(80) = NULL,
    @Primer_Apellido VARCHAR(80) = NULL,
    @Segundo_Apellido VARCHAR(80) = NULL,
    @Id_Tipo_DNI INT = NULL,
    @DNI VARCHAR(20) = NULL,
    @Id_Genero INT = NULL,
    @Id_Nacionalidad INT = NULL,
    @Id_Creador INT = NULL,
    @Id_Modificador INT = NULL,
    @Id_Estado INT = NULL,
    @Filtro VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Mode = 'INS'
    BEGIN
        IF @Primer_Nombre IS NULL OR @Primer_Apellido IS NULL OR @DNI IS NULL OR
           @Id_Tipo_DNI IS NULL OR @Id_Genero IS NULL OR @Id_Nacionalidad IS NULL OR
           @Id_Creador IS NULL OR @Id_Modificador IS NULL OR @Id_Estado IS NULL
        BEGIN
            SET @O_Msg = 'Faltan campos obligatorios.';
            SET @O_Num = -1;
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM Tbl_Datos_Personales WHERE DNI = @DNI)
        BEGIN
            SET @O_Msg = 'Ya existe una persona con ese DNI.';
            SET @O_Num = -1;
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Cls_Catalogos WHERE Id_Catalogo = @Id_Tipo_DNI)
        BEGIN
            SET @O_Msg = 'El tipo de DNI especificado no existe.';
            SET @O_Num = -1;
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Cls_Catalogos WHERE Id_Catalogo = @Id_Genero)
        BEGIN
            SET @O_Msg = 'El género especificado no existe.';
            SET @O_Num = -1;
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Cls_Catalogos WHERE Id_Catalogo = @Id_Nacionalidad)
        BEGIN
            SET @O_Msg = 'La nacionalidad especificada no existe.';
            SET @O_Num = -1;
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Cls_Estados WHERE Id_Estado = @Id_Estado)
        BEGIN
            SET @O_Msg = 'El estado especificado no existe.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            INSERT INTO Tbl_Datos_Personales (
                Primer_Nombre, Segundo_Nombre, Primer_Apellido, Segundo_Apellido,
                Id_Tipo_DNI, DNI, Id_Genero, Id_Nacionalidad,
                Fecha_Creacion, Fecha_Modificacion,
                Id_Creador, Id_Modificador, Id_Estado
            )
            VALUES (
                @Primer_Nombre, @Segundo_Nombre, @Primer_Apellido, @Segundo_Apellido,
                @Id_Tipo_DNI, @DNI, @Id_Genero, @Id_Nacionalidad,
                GETDATE(), GETDATE(), @Id_Creador, @Id_Modificador, @Id_Estado
            );

            SET @O_Num = SCOPE_IDENTITY();
            SET @O_Msg = 'Persona registrada correctamente.';
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
        IF @Id_Persona IS NULL
        BEGIN
            SET @O_Msg = 'Id_Persona requerido para actualizar.';
            SET @O_Num = -1;
            RETURN;
        END

        IF @DNI IS NOT NULL
        BEGIN
            IF EXISTS (
                SELECT 1 FROM Tbl_Datos_Personales
                WHERE DNI = @DNI AND Id_Persona <> @Id_Persona
            )
            BEGIN
                SET @O_Msg = 'Ya existe otra persona con ese DNI.';
                SET @O_Num = -1;
                RETURN;
            END
        END

        BEGIN TRY
            BEGIN TRAN;

            UPDATE Tbl_Datos_Personales
            SET Primer_Nombre = COALESCE(@Primer_Nombre, Primer_Nombre),
                Segundo_Nombre = COALESCE(@Segundo_Nombre, Segundo_Nombre),
                Primer_Apellido = COALESCE(@Primer_Apellido, Primer_Apellido),
                Segundo_Apellido = COALESCE(@Segundo_Apellido, Segundo_Apellido),
                Id_Tipo_DNI = COALESCE(@Id_Tipo_DNI, Id_Tipo_DNI),
                DNI = COALESCE(@DNI, DNI),
                Id_Genero = COALESCE(@Id_Genero, Id_Genero),
                Id_Nacionalidad = COALESCE(@Id_Nacionalidad, Id_Nacionalidad),
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = COALESCE(@Id_Modificador, Id_Modificador),
                Id_Estado = COALESCE(@Id_Estado, Id_Estado)
            WHERE Id_Persona = @Id_Persona;

            SET @O_Num = @Id_Persona;
            SET @O_Msg = 'Persona actualizada correctamente.';
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
        IF @Id_Persona IS NULL OR @Id_Modificador IS NULL
        BEGIN
            SET @O_Msg = 'Id_Persona e Id_Modificador requeridos.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            UPDATE Tbl_Datos_Personales
            SET Id_Estado = 2,
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = @Id_Modificador
            WHERE Id_Persona = @Id_Persona;

            SET @O_Num = @Id_Persona;
            SET @O_Msg = 'Persona inactivada correctamente.';
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
            dp.Id_Persona,
            dp.Primer_Nombre,
            dp.Segundo_Nombre,
            dp.Primer_Apellido,
            dp.Segundo_Apellido,
            dp.Id_Tipo_DNI,
            cDNI.Catalogo AS Tipo_DNI,
            dp.DNI,
            dp.Id_Genero,
            cGen.Catalogo AS Genero,
            dp.Id_Nacionalidad,
            cNac.Catalogo AS Nacionalidad,
            dp.Fecha_Creacion,
            dp.Fecha_Modificacion,
            dp.Id_Creador,
            dp.Id_Modificador,
            dp.Id_Estado,
            e.Estado
        FROM Tbl_Datos_Personales dp
        LEFT JOIN Cls_Catalogos cDNI ON dp.Id_Tipo_DNI = cDNI.Id_Catalogo
        LEFT JOIN Cls_Catalogos cGen ON dp.Id_Genero = cGen.Id_Catalogo
        LEFT JOIN Cls_Catalogos cNac ON dp.Id_Nacionalidad = cNac.Id_Catalogo
        JOIN Cls_Estados e ON dp.Id_Estado = e.Id_Estado
        ORDER BY dp.Primer_Apellido, dp.Primer_Nombre;

        SET @O_Msg = 'Listado de personas.';
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
                dp.Id_Persona,
                dp.Primer_Nombre,
                dp.Segundo_Nombre,
                dp.Primer_Apellido,
                dp.Segundo_Apellido,
                dp.Id_Tipo_DNI,
                cDNI.Catalogo AS Tipo_DNI,
                dp.DNI,
                dp.Id_Genero,
                cGen.Catalogo AS Genero,
                dp.Id_Nacionalidad,
                cNac.Catalogo AS Nacionalidad,
                dp.Fecha_Creacion,
                dp.Fecha_Modificacion,
                dp.Id_Creador,
                dp.Id_Modificador,
                dp.Id_Estado,
                e.Estado
            FROM Tbl_Datos_Personales dp
            LEFT JOIN Cls_Catalogos cDNI ON dp.Id_Tipo_DNI = cDNI.Id_Catalogo
            LEFT JOIN Cls_Catalogos cGen ON dp.Id_Genero = cGen.Id_Catalogo
            LEFT JOIN Cls_Catalogos cNac ON dp.Id_Nacionalidad = cNac.Id_Catalogo
            JOIN Cls_Estados e ON dp.Id_Estado = e.Id_Estado
            WHERE dp.Primer_Nombre LIKE '%' + @Filtro + '%'
               OR dp.Primer_Apellido LIKE '%' + @Filtro + '%'
               OR dp.DNI LIKE '%' + @Filtro + '%'
               OR CAST(dp.Id_Persona AS VARCHAR) = @Filtro
            ORDER BY dp.Primer_Apellido, dp.Primer_Nombre;

            IF @@ROWCOUNT > 0
            BEGIN
                SET @O_Msg = 'Consulta con filtro realizada.';
                SET @O_Num = 0;
            END
            ELSE
            BEGIN
                SET @O_Msg = 'No se encontraron personas con ese filtro.';
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