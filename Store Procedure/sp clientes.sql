USE NicaTek;
GO

CREATE OR ALTER PROC sp_Tbl_Cliente
    @Mode VARCHAR(3) = NULL,
    @O_Msg VARCHAR(255) = NULL OUTPUT,
    @O_Num INT = NULL OUTPUT,
    @Id_Cliente INT = NULL,
    @Id_Persona INT = NULL,
    @Id_Estado INT = NULL,
    @Id_Creador INT = NULL,
    @Id_Modificador INT = NULL,
    @Filtro VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Mode = 'INS'
    BEGIN
        IF @Id_Persona IS NULL OR @Id_Estado IS NULL OR @Id_Creador IS NULL OR @Id_Modificador IS NULL
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

        IF EXISTS (SELECT 1 FROM Tbl_Cliente WHERE Id_Persona = @Id_Persona)
        BEGIN
            SET @O_Msg = 'Esta persona ya está registrada como cliente.';
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

            INSERT INTO Tbl_Cliente (
                Id_Persona, Id_Estado,
                Fecha_Creacion, Fecha_Modificacion,
                Id_Creador, Id_Modificador
            )
            VALUES (
                @Id_Persona, @Id_Estado,
                GETDATE(), GETDATE(),
                @Id_Creador, @Id_Modificador
            );

            SET @O_Num = SCOPE_IDENTITY();
            SET @O_Msg = 'Cliente registrado correctamente.';
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
        IF @Id_Cliente IS NULL
        BEGIN
            SET @O_Msg = 'Id_Cliente requerido para actualizar.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            UPDATE Tbl_Cliente
            SET Id_Persona = COALESCE(@Id_Persona, Id_Persona),
                Id_Estado = COALESCE(@Id_Estado, Id_Estado),
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = COALESCE(@Id_Modificador, Id_Modificador)
            WHERE Id_Cliente = @Id_Cliente;

            IF @@ROWCOUNT = 0
            BEGIN
                ROLLBACK;
                SET @O_Msg = 'No se actualizó ninguna fila. Verificá el Id_Cliente.';
                SET @O_Num = -1;
                RETURN;
            END

            SET @O_Num = @Id_Cliente;
            SET @O_Msg = 'Cliente actualizado correctamente.';
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
        IF @Id_Cliente IS NULL OR @Id_Modificador IS NULL
        BEGIN
            SET @O_Msg = 'Id_Cliente e Id_Modificador requeridos.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            UPDATE Tbl_Cliente
            SET Id_Estado = 2,
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = @Id_Modificador
            WHERE Id_Cliente = @Id_Cliente;

            SET @O_Num = @Id_Cliente;
            SET @O_Msg = 'Cliente inactivado correctamente.';
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
            c.Id_Cliente,
            c.Id_Persona,
            (ISNULL(dp.Primer_Nombre, '') + ' ' + ISNULL(dp.Segundo_Nombre, '') + ' ' + ISNULL(dp.Primer_Apellido, '') + ' ' + ISNULL(dp.Segundo_Apellido, '')) AS Nombre_Completo,
            c.Id_Estado,
            e.Estado,
            c.Fecha_Creacion,
            c.Fecha_Modificacion,
            c.Id_Creador,
            c.Id_Modificador
        FROM Tbl_Cliente c
        JOIN Tbl_Datos_Personales dp ON c.Id_Persona = dp.Id_Persona
        JOIN Cls_Estados e ON c.Id_Estado = e.Id_Estado;

        SET @O_Msg = 'Listado de clientes.';
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
                c.Id_Cliente,
                c.Id_Persona,
                (ISNULL(dp.Primer_Nombre, '') + ' ' + ISNULL(dp.Segundo_Nombre, '') + ' ' + ISNULL(dp.Primer_Apellido, '') + ' ' + ISNULL(dp.Segundo_Apellido, '')) AS Nombre_Completo,
                c.Id_Estado,
                e.Estado,
                c.Fecha_Creacion,
                c.Fecha_Modificacion,
                c.Id_Creador,
                c.Id_Modificador
            FROM Tbl_Cliente c
            JOIN Tbl_Datos_Personales dp ON c.Id_Persona = dp.Id_Persona
            JOIN Cls_Estados e ON c.Id_Estado = e.Id_Estado
            WHERE (CAST(c.Id_Cliente AS VARCHAR) = @Filtro
                OR CAST(c.Id_Persona AS VARCHAR) = @Filtro
                OR dp.Primer_Nombre LIKE '%' + @Filtro + '%'
                OR dp.Segundo_Nombre LIKE '%' + @Filtro + '%'
                OR dp.Primer_Apellido LIKE '%' + @Filtro + '%'
                OR dp.Segundo_Apellido LIKE '%' + @Filtro + '%'
                OR e.Estado LIKE '%' + @Filtro + '%');

            SET @O_Msg = 'Consulta con filtro realizada.';
            SET @O_Num = 0;
        END
    END

    ELSE
    BEGIN
        SET @O_Msg = 'Modo no reconocido.';
        SET @O_Num = -1;
    END
END
GO