USE [NICATEK]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[sp_Tbl_Proveedor]
    @Mode VARCHAR(3) = NULL,
    @O_Msg VARCHAR(255) = NULL OUTPUT,
    @O_Num INT = NULL OUTPUT,

    @Id_Proveedor INT = NULL,
    @Id_Persona INT = NULL,

    @Cedula VARCHAR(20) = NULL,
    @Primer_Nombre VARCHAR(50) = NULL,
    @Segundo_Nombre VARCHAR(50) = NULL,
    @Primer_Apellido VARCHAR(50) = NULL,
    @Segundo_Apellido VARCHAR(50) = NULL,

    @FechaRegistro DATETIME = NULL,
    @Fecha_Terminacion_Contrato DATETIME = NULL,
    @Id_Estado INT = NULL,

    @Id_Creador INT = NULL,
    @Id_Modificador INT = NULL,
    @Filtro VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Mode = 'INS'
    BEGIN
        -- Si viene Id_Persona, la persona ya existe — solo insertamos el proveedor
        IF @Id_Persona IS NOT NULL
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM Tbl_Datos_Personales WHERE Id_Persona = @Id_Persona)
            BEGIN
                SET @O_Msg = 'No existe una persona con ese Id_Persona.';
                SET @O_Num = -1;
                RETURN;
            END

            IF EXISTS (SELECT 1 FROM Tbl_Proveedor WHERE Id_Persona = @Id_Persona AND Id_Estado = 1)
            BEGIN
                SET @O_Msg = 'Esta persona ya está registrada como proveedor activo.';
                SET @O_Num = -1;
                RETURN;
            END

            BEGIN TRY
                BEGIN TRAN;

                INSERT INTO Tbl_Proveedor (
                    Id_Persona, FechaRegistro, Fecha_Terminacion_Contrato,
                    Id_Estado, Id_Creador, Id_Modificador
                )
                VALUES (
                    @Id_Persona, COALESCE(@FechaRegistro, GETDATE()), @Fecha_Terminacion_Contrato,
                    @Id_Estado, @Id_Creador, @Id_Modificador
                );

                SET @O_Num = SCOPE_IDENTITY();
                SET @O_Msg = 'Proveedor registrado con éxito';
                COMMIT;
            END TRY
            BEGIN CATCH
                ROLLBACK;
                SET @O_Msg = ERROR_MESSAGE();
                SET @O_Num = ERROR_NUMBER();
            END CATCH
        END
        ELSE
        BEGIN
            -- Flujo original: crear persona nueva y luego proveedor
            IF @Cedula IS NULL OR @Primer_Nombre IS NULL OR @Primer_Apellido IS NULL OR @Id_Estado IS NULL
            BEGIN
                SET @O_Msg = 'Faltan campos obligatorios (Cédula, Nombres, Estado).';
                SET @O_Num = -1;
                RETURN;
            END

            IF EXISTS (SELECT 1 FROM Tbl_Datos_Personales WHERE DNI = @Cedula)
            BEGIN
                SET @O_Msg = 'Ya existe una persona registrada con esa Cédula.';
                SET @O_Num = -1;
                RETURN;
            END

            BEGIN TRY
                BEGIN TRAN;

                INSERT INTO Tbl_Datos_Personales (
                    Primer_Nombre, Segundo_Nombre, Primer_Apellido, Segundo_Apellido, DNI,
                    Fecha_Creacion, Id_Creador, Id_Estado
                )
                VALUES (
                    @Primer_Nombre, @Segundo_Nombre, @Primer_Apellido, @Segundo_Apellido, @Cedula,
                    GETDATE(), @Id_Creador, 1
                );

                SET @Id_Persona = SCOPE_IDENTITY();

                INSERT INTO Tbl_Proveedor (
                    Id_Persona, FechaRegistro, Fecha_Terminacion_Contrato,
                    Id_Estado, Id_Creador, Id_Modificador
                )
                VALUES (
                    @Id_Persona, COALESCE(@FechaRegistro, GETDATE()), @Fecha_Terminacion_Contrato,
                    @Id_Estado, @Id_Creador, @Id_Modificador
                );

                SET @O_Num = SCOPE_IDENTITY();
                SET @O_Msg = 'Proveedor registrado correctamente.';
                COMMIT;
            END TRY
            BEGIN CATCH
                ROLLBACK;
                SET @O_Msg = ERROR_MESSAGE();
                SET @O_Num = ERROR_NUMBER();
            END CATCH
        END
    END

    ELSE IF @Mode = 'UPD'
    BEGIN
        IF @Id_Proveedor IS NULL
        BEGIN
            SET @O_Msg = 'Id_Proveedor requerido para actualizar.';
            SET @O_Num = -1;
            RETURN;
        END

        SELECT @Id_Persona = Id_Persona FROM Tbl_Proveedor WHERE Id_Proveedor = @Id_Proveedor;

        BEGIN TRY
            BEGIN TRAN;

            UPDATE Tbl_Datos_Personales
            SET Primer_Nombre = COALESCE(@Primer_Nombre, Primer_Nombre),
                Segundo_Nombre = COALESCE(@Segundo_Nombre, Segundo_Nombre),
                Primer_Apellido = COALESCE(@Primer_Apellido, Primer_Apellido),
                Segundo_Apellido = COALESCE(@Segundo_Apellido, Segundo_Apellido),
                DNI = COALESCE(@Cedula, DNI),
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = @Id_Modificador
            WHERE Id_Persona = @Id_Persona;

            UPDATE Tbl_Proveedor
            SET Fecha_Terminacion_Contrato = COALESCE(@Fecha_Terminacion_Contrato, Fecha_Terminacion_Contrato),
                Id_Estado = COALESCE(@Id_Estado, Id_Estado),
                FechaRegistro = COALESCE(@FechaRegistro, FechaRegistro),
                Id_Modificador = COALESCE(@Id_Modificador, Id_Modificador)
            WHERE Id_Proveedor = @Id_Proveedor;

            SET @O_Num = @Id_Proveedor;
            SET @O_Msg = 'Proveedor actualizado correctamente.';
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
        IF @Id_Proveedor IS NULL OR @Id_Modificador IS NULL
        BEGIN
            SET @O_Msg = 'Id_Proveedor e Id_Modificador requeridos.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            UPDATE Tbl_Proveedor
            SET Id_Estado = 2,
                Id_Modificador = @Id_Modificador
            WHERE Id_Proveedor = @Id_Proveedor;

            SET @O_Num = @Id_Proveedor;
            SET @O_Msg = 'Proveedor inactivado correctamente.';
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
            p.Id_Proveedor,
            p.Id_Persona,
            dp.DNI AS Cedula,
            dp.Primer_Nombre,
            dp.Segundo_Nombre,
            dp.Primer_Apellido,
            dp.Segundo_Apellido,
            p.FechaRegistro,
            p.Fecha_Terminacion_Contrato,
            p.Id_Estado,
            est.Estado,
            p.Id_Creador,
            p.Id_Modificador
        FROM Tbl_Proveedor p
        JOIN Tbl_Datos_Personales dp ON p.Id_Persona = dp.Id_Persona
        JOIN Cls_Estados est ON p.Id_Estado = est.Id_Estado;

        SET @O_Msg = 'Listado de proveedores.';
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
            p.Id_Proveedor,
            p.Id_Persona,
            dp.DNI AS Cedula,
            dp.Primer_Nombre,
            dp.Segundo_Nombre,
            dp.Primer_Apellido,
            dp.Segundo_Apellido,
            p.FechaRegistro,
            p.Fecha_Terminacion_Contrato,
            p.Id_Estado,
            est.Estado,
            p.Id_Creador,
            p.Id_Modificador
        FROM Tbl_Proveedor p
        JOIN Tbl_Datos_Personales dp ON p.Id_Persona = dp.Id_Persona
        JOIN Cls_Estados est ON p.Id_Estado = est.Id_Estado
        WHERE (CAST(p.Id_Proveedor AS VARCHAR) = @Filtro
            OR dp.DNI LIKE '%' + @Filtro + '%'
            OR dp.Primer_Nombre LIKE '%' + @Filtro + '%'
            OR dp.Segundo_Nombre LIKE '%' + @Filtro + '%'
            OR dp.Primer_Apellido LIKE '%' + @Filtro + '%'
            OR dp.Segundo_Apellido LIKE '%' + @Filtro + '%'
            OR est.Estado LIKE '%' + @Filtro + '%');

        SET @O_Msg = 'Consulta filtrada realizada.';
        SET @O_Num = 0;
    END
END