USE NicaTek;
GO

CREATE OR ALTER PROC sp_Tbl_Direcciones
    @Mode VARCHAR(3) = NULL,
    @O_Msg VARCHAR(255) = NULL OUTPUT,
    @O_Num INT = NULL OUTPUT,
    @Id_Direccion INT = NULL,
    @Direccion_Completa VARCHAR(255) = NULL,
    @Id_Tipo_Direccion INT = NULL,
    @Id_Persona INT = NULL,
    @Id_Creador INT = NULL,
    @Id_Modificador INT = NULL,
    @Activo BIT = NULL,
    @Filtro VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Mode = 'INS'
    BEGIN
        IF @Direccion_Completa IS NULL OR @Id_Tipo_Direccion IS NULL OR
           @Id_Persona IS NULL OR @Id_Creador IS NULL OR
           @Id_Modificador IS NULL OR @Activo IS NULL
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

        IF NOT EXISTS (SELECT 1 FROM Cls_Catalogos WHERE Id_Catalogo = @Id_Tipo_Direccion)
        BEGIN
            SET @O_Msg = 'El tipo de dirección especificado no existe.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            INSERT INTO Tbl_Direcciones (
                Direccion_Completa, Id_Tipo_Direccion, Id_Persona,
                Fecha_Creacion, Fecha_Modificacion,
                Id_Creador, Id_Modificador, Activo
            )
            VALUES (
                @Direccion_Completa, @Id_Tipo_Direccion, @Id_Persona,
                GETDATE(), GETDATE(),
                @Id_Creador, @Id_Modificador, @Activo
            );

            SET @O_Num = SCOPE_IDENTITY();
            SET @O_Msg = 'Dirección registrada correctamente.';
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
        IF @Id_Direccion IS NULL
        BEGIN
            SET @O_Msg = 'Id_Direccion requerido para actualizar.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            UPDATE Tbl_Direcciones
            SET Direccion_Completa = COALESCE(@Direccion_Completa, Direccion_Completa),
                Id_Tipo_Direccion = COALESCE(@Id_Tipo_Direccion, Id_Tipo_Direccion),
                Id_Persona = COALESCE(@Id_Persona, Id_Persona),
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = COALESCE(@Id_Modificador, Id_Modificador),
                Activo = COALESCE(@Activo, Activo)
            WHERE Id_Direccion = @Id_Direccion;

            SET @O_Num = @Id_Direccion;
            SET @O_Msg = 'Dirección actualizada correctamente.';
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
        IF @Id_Direccion IS NULL OR @Id_Modificador IS NULL
        BEGIN
            SET @O_Msg = 'Id_Direccion e Id_Modificador requeridos.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            UPDATE Tbl_Direcciones
            SET Activo = 0,
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = @Id_Modificador
            WHERE Id_Direccion = @Id_Direccion;

            SET @O_Num = @Id_Direccion;
            SET @O_Msg = 'Dirección inactivada correctamente.';
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
            d.Id_Direccion,
            d.Direccion_Completa,
            d.Id_Tipo_Direccion,
            c.Catalogo AS Tipo_Direccion,
            d.Id_Persona,
            (ISNULL(dp.Primer_Nombre, '') + ' ' + ISNULL(dp.Primer_Apellido, '')) AS Nombre_Completo,
            d.Fecha_Creacion,
            d.Fecha_Modificacion,
            d.Activo,
            CASE WHEN d.Activo = 1 THEN 'Sí' ELSE 'No' END AS EstadoActivo
        FROM Tbl_Direcciones d
        JOIN Cls_Catalogos c ON d.Id_Tipo_Direccion = c.Id_Catalogo
        JOIN Tbl_Datos_Personales dp ON d.Id_Persona = dp.Id_Persona;

        SET @O_Msg = 'Listado de direcciones.';
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
                d.Id_Direccion,
                d.Direccion_Completa,
                d.Id_Tipo_Direccion,
                c.Catalogo AS Tipo_Direccion,
                d.Id_Persona,
                (ISNULL(dp.Primer_Nombre, '') + ' ' + ISNULL(dp.Primer_Apellido, '')) AS Nombre_Completo,
                d.Fecha_Creacion,
                d.Fecha_Modificacion,
                d.Activo,
                CASE WHEN d.Activo = 1 THEN 'Sí' ELSE 'No' END AS EstadoActivo
            FROM Tbl_Direcciones d
            JOIN Cls_Catalogos c ON d.Id_Tipo_Direccion = c.Id_Catalogo
            JOIN Tbl_Datos_Personales dp ON d.Id_Persona = dp.Id_Persona
            WHERE d.Direccion_Completa LIKE '%' + @Filtro + '%'
               OR CAST(d.Id_Direccion AS VARCHAR) = @Filtro
               OR c.Catalogo LIKE '%' + @Filtro + '%'
               OR dp.Primer_Nombre LIKE '%' + @Filtro + '%'
               OR dp.Primer_Apellido LIKE '%' + @Filtro + '%'
               OR (@FiltroInt IS NOT NULL AND d.Id_Persona = @FiltroInt);

            IF @@ROWCOUNT > 0
            BEGIN
                SET @O_Msg = 'Consulta con filtro realizada.';
                SET @O_Num = 0;
            END
            ELSE
            BEGIN
                SET @O_Msg = 'No se encontraron direcciones con ese filtro.';
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