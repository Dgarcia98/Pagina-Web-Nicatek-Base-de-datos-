USE NicaTek;
GO

CREATE OR ALTER PROC sp_Tbl_Correos
    @Mode VARCHAR(3) = NULL,
    @O_Msg VARCHAR(255) = NULL OUTPUT,
    @O_Num INT = NULL OUTPUT,
    @Id_Correo INT = NULL,
    @Id_Persona INT = NULL,
    @Direccion_Correo VARCHAR(100) = NULL,
    @Id_Tipo_Correo INT = NULL,
    @Id_Creador INT = NULL,
    @Id_Modificador INT = NULL,
    @Activo BIT = NULL,
    @Filtro VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Mode = 'INS'
    BEGIN
        IF @Id_Persona IS NULL OR @Direccion_Correo IS NULL OR @Id_Tipo_Correo IS NULL OR
           @Id_Creador IS NULL OR @Id_Modificador IS NULL OR @Activo IS NULL
        BEGIN
            SET @O_Msg = 'Faltan campos obligatorios.';
            SET @O_Num = -1;
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Tbl_Datos_Personales WHERE Id_Persona = @Id_Persona)
        BEGIN
            SET @O_Msg = 'La persona especificada no existe.';
            SET @O_Num = -1;
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Cls_Catalogos WHERE Id_Catalogo = @Id_Tipo_Correo)
        BEGIN
            SET @O_Msg = 'El tipo de correo especificado no existe.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            INSERT INTO Tbl_Correos (
                Id_Persona, Direccion_Correo, Id_Tipo_Correo,
                Fecha_Creacion, Fecha_Modificacion,
                Id_Creador, Id_Modificador, Activo
            )
            VALUES (
                @Id_Persona, @Direccion_Correo, @Id_Tipo_Correo,
                GETDATE(), GETDATE(), @Id_Creador, @Id_Modificador, @Activo
            );

            SET @O_Num = SCOPE_IDENTITY();
            SET @O_Msg = 'Correo registrado correctamente.';
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
        IF @Id_Correo IS NULL
        BEGIN
            SET @O_Msg = 'Id_Correo requerido para actualizar.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            UPDATE Tbl_Correos
            SET Direccion_Correo = COALESCE(@Direccion_Correo, Direccion_Correo),
                Id_Tipo_Correo = COALESCE(@Id_Tipo_Correo, Id_Tipo_Correo),
                Id_Persona = COALESCE(@Id_Persona, Id_Persona),
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = COALESCE(@Id_Modificador, Id_Modificador),
                Activo = COALESCE(@Activo, Activo)
            WHERE Id_Correo = @Id_Correo;

            IF @@ROWCOUNT = 0
            BEGIN
                ROLLBACK;
                SET @O_Msg = 'No se actualizó ninguna fila. Verificá el Id_Correo.';
                SET @O_Num = -1;
                RETURN;
            END

            SET @O_Num = @Id_Correo;
            SET @O_Msg = 'Correo actualizado correctamente.';
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
        IF @Id_Correo IS NULL OR @Id_Modificador IS NULL
        BEGIN
            SET @O_Msg = 'Id_Correo e Id_Modificador requeridos.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            UPDATE Tbl_Correos
            SET Activo = 0,
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = @Id_Modificador
            WHERE Id_Correo = @Id_Correo;

            SET @O_Num = @Id_Correo;
            SET @O_Msg = 'Correo inactivado correctamente.';
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
            c.Id_Correo,
            c.Direccion_Correo,
            c.Id_Tipo_Correo,
            cat.Catalogo AS Tipo_Correo,
            c.Id_Persona,
            (ISNULL(dp.Primer_Nombre, '') + ' ' + ISNULL(dp.Primer_Apellido, '')) AS Nombre_Completo,
            c.Fecha_Creacion,
            c.Fecha_Modificacion,
            c.Activo,
            CASE WHEN c.Activo = 1 THEN 'Sí' ELSE 'No' END AS EstadoActivo
        FROM Tbl_Correos c
        JOIN Cls_Catalogos cat ON c.Id_Tipo_Correo = cat.Id_Catalogo
        JOIN Tbl_Datos_Personales dp ON c.Id_Persona = dp.Id_Persona;

        SET @O_Msg = 'Listado de correos.';
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
            DECLARE @FiltroInt INT;
            SET @FiltroInt = TRY_CAST(@Filtro AS INT);

            SELECT 
                c.Id_Correo,
                c.Direccion_Correo,
                c.Id_Tipo_Correo,
                cat.Catalogo AS Tipo_Correo,
                c.Id_Persona,
                (ISNULL(dp.Primer_Nombre, '') + ' ' + ISNULL(dp.Primer_Apellido, '')) AS Nombre_Completo,
                c.Fecha_Creacion,
                c.Fecha_Modificacion,
                c.Activo,
                CASE WHEN c.Activo = 1 THEN 'Sí' ELSE 'No' END AS EstadoActivo
            FROM Tbl_Correos c
            JOIN Cls_Catalogos cat ON c.Id_Tipo_Correo = cat.Id_Catalogo
            JOIN Tbl_Datos_Personales dp ON c.Id_Persona = dp.Id_Persona
            WHERE c.Direccion_Correo LIKE '%' + @Filtro + '%'
               OR CAST(c.Id_Correo AS VARCHAR) = @Filtro
               OR cat.Catalogo LIKE '%' + @Filtro + '%'
               OR dp.Primer_Nombre LIKE '%' + @Filtro + '%'
               OR dp.Primer_Apellido LIKE '%' + @Filtro + '%'
               OR (@FiltroInt IS NOT NULL AND c.Id_Persona = @FiltroInt);

            IF @@ROWCOUNT > 0
            BEGIN
                SET @O_Msg = 'Consulta con filtro realizada.';
                SET @O_Num = 0;
            END
            ELSE
            BEGIN
                SET @O_Msg = 'No se encontraron correos con ese filtro.';
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