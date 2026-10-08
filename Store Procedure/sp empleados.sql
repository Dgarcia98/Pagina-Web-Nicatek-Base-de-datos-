USE NicaTek;
GO

CREATE OR ALTER PROC sp_Empleado
    @Mode VARCHAR(3) = NULL,
    @O_Msg VARCHAR(255) = NULL OUTPUT,
    @O_Num INT = NULL OUTPUT,
    @Id_Empleado INT = NULL,
    @Id_Persona INT = NULL,
    @Fecha_Contratacion DATE = NULL,
    @Fecha_Despido DATE = NULL,
    @Id_Cargo INT = NULL,
    @Id_Estado INT = NULL,
    @Id_Creador INT = NULL,
    @Id_Modificador INT = NULL,
    @Filtro VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Mode = 'INS'
    BEGIN
        IF @Id_Persona IS NULL OR @Fecha_Contratacion IS NULL OR @Id_Cargo IS NULL OR
           @Id_Estado IS NULL OR @Id_Creador IS NULL OR @Id_Modificador IS NULL
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

        IF NOT EXISTS (SELECT 1 FROM Cls_Catalogos WHERE Id_Catalogo = @Id_Cargo)
        BEGIN
            SET @O_Msg = 'El cargo especificado no existe.';
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

            INSERT INTO Tbl_Empleado (
                Id_Persona, Fecha_Contratacion, Fecha_Despido,
                Id_Cargo, Id_Estado, Fecha_Creacion, Fecha_Modificacion,
                Id_Creador, Id_Modificador
            )
            VALUES (
                @Id_Persona, @Fecha_Contratacion, @Fecha_Despido,
                @Id_Cargo, @Id_Estado, GETDATE(), GETDATE(),
                @Id_Creador, @Id_Modificador
            );

            SET @O_Num = SCOPE_IDENTITY();
            SET @O_Msg = 'Empleado registrado correctamente.';
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
        IF @Id_Empleado IS NULL
        BEGIN
            SET @O_Msg = 'Id_Empleado requerido para actualizar.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            UPDATE Tbl_Empleado
            SET Id_Persona = COALESCE(@Id_Persona, Id_Persona),
                Fecha_Contratacion = COALESCE(@Fecha_Contratacion, Fecha_Contratacion),
                Fecha_Despido = COALESCE(@Fecha_Despido, Fecha_Despido),
                Id_Cargo = COALESCE(@Id_Cargo, Id_Cargo),
                Id_Estado = COALESCE(@Id_Estado, Id_Estado),
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = COALESCE(@Id_Modificador, Id_Modificador)
            WHERE Id_Empleado = @Id_Empleado;

            SET @O_Num = @Id_Empleado;
            SET @O_Msg = 'Empleado actualizado correctamente.';
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
        IF @Id_Empleado IS NULL OR @Id_Modificador IS NULL
        BEGIN
            SET @O_Msg = 'Id_Empleado e Id_Modificador requeridos.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            UPDATE Tbl_Empleado
            SET Id_Estado = 2,
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = @Id_Modificador
            WHERE Id_Empleado = @Id_Empleado;

            SET @O_Num = @Id_Empleado;
            SET @O_Msg = 'Empleado inactivado correctamente.';
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
            e.Id_Empleado,
            e.Id_Persona,
            (ISNULL(p.Primer_Nombre, '') + ' ' + ISNULL(p.Primer_Apellido, '')) AS Nombre_Completo,
            p.DNI AS Cedula,
            e.Fecha_Contratacion,
            e.Fecha_Despido,
            e.Id_Cargo,
            c.Catalogo AS Cargo,
            e.Id_Estado,
            s.Estado,
            e.Fecha_Creacion,
            e.Fecha_Modificacion,
            e.Id_Creador,
            e.Id_Modificador
        FROM Tbl_Empleado e
        JOIN Tbl_Datos_Personales p ON e.Id_Persona = p.Id_Persona
        LEFT JOIN Cls_Catalogos c ON e.Id_Cargo = c.Id_Catalogo
        JOIN Cls_Estados s ON e.Id_Estado = s.Id_Estado;

        SET @O_Msg = 'Listado de empleados.';
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
                e.Id_Empleado,
                e.Id_Persona,
                (ISNULL(p.Primer_Nombre, '') + ' ' + ISNULL(p.Primer_Apellido, '')) AS Nombre_Completo,
                p.DNI AS Cedula,
                e.Fecha_Contratacion,
                e.Fecha_Despido,
                e.Id_Cargo,
                c.Catalogo AS Cargo,
                e.Id_Estado,
                s.Estado,
                e.Fecha_Creacion,
                e.Fecha_Modificacion,
                e.Id_Creador,
                e.Id_Modificador
            FROM Tbl_Empleado e
            JOIN Tbl_Datos_Personales p ON e.Id_Persona = p.Id_Persona
            LEFT JOIN Cls_Catalogos c ON e.Id_Cargo = c.Id_Catalogo
            JOIN Cls_Estados s ON e.Id_Estado = s.Id_Estado
            WHERE CAST(e.Id_Empleado AS VARCHAR) = @Filtro
               OR p.DNI LIKE '%' + @Filtro + '%'
               OR p.Primer_Nombre LIKE '%' + @Filtro + '%'
               OR p.Primer_Apellido LIKE '%' + @Filtro + '%'
               OR c.Catalogo LIKE '%' + @Filtro + '%';

            IF @@ROWCOUNT > 0
            BEGIN
                SET @O_Msg = 'Consulta con filtro realizada.';
                SET @O_Num = 0;
            END
            ELSE
            BEGIN
                SET @O_Msg = 'No se encontraron empleados con ese filtro.';
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