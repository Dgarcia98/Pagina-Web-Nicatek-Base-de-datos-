USE NicaTek;
GO

CREATE OR ALTER PROC sp_Cls_Roles
    @Mode VARCHAR(3) = NULL,
    @O_Msg VARCHAR(255) = NULL OUTPUT,
    @O_Num INT = NULL OUTPUT,
    @Id_Rol INT = NULL,
    @Nombre_Rol VARCHAR(80) = NULL,
    @Descripcion VARCHAR(255) = NULL,
    @Id_Creador INT = NULL,
    @Id_Modificador INT = NULL,
    @Activo BIT = NULL,
    @Filtro VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Mode = 'INS'
    BEGIN
        IF @Nombre_Rol IS NULL OR @Id_Creador IS NULL OR @Id_Modificador IS NULL OR @Activo IS NULL
        BEGIN
            SET @O_Msg = 'Faltan campos obligatorios.';
            SET @O_Num = -1;
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM Cls_Roles WHERE Nombre_Rol = @Nombre_Rol)
        BEGIN
            SET @O_Msg = 'Ya existe un rol con ese nombre.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            INSERT INTO Cls_Roles (
                Nombre_Rol, Descripcion, Fecha_Creacion, Fecha_Modificacion,
                Id_Creador, Id_Modificador, Activo
            )
            VALUES (
                @Nombre_Rol, @Descripcion, GETDATE(), GETDATE(),
                @Id_Creador, @Id_Modificador, @Activo
            );

            SET @O_Num = SCOPE_IDENTITY();
            SET @O_Msg = 'Rol registrado correctamente.';
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
        IF @Id_Rol IS NULL
        BEGIN
            SET @O_Msg = 'Id_Rol requerido para actualizar.';
            SET @O_Num = -1;
            RETURN;
        END

        IF @Nombre_Rol IS NOT NULL
        BEGIN
            IF EXISTS (SELECT 1 FROM Cls_Roles WHERE Nombre_Rol = @Nombre_Rol AND Id_Rol <> @Id_Rol)
            BEGIN
                SET @O_Msg = 'Ya existe otro rol con ese nombre.';
                SET @O_Num = -1;
                RETURN;
            END
        END

        BEGIN TRY
            BEGIN TRAN;

            UPDATE Cls_Roles
            SET Nombre_Rol = COALESCE(@Nombre_Rol, Nombre_Rol),
                Descripcion = COALESCE(@Descripcion, Descripcion),
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = COALESCE(@Id_Modificador, Id_Modificador),
                Activo = COALESCE(@Activo, Activo)
            WHERE Id_Rol = @Id_Rol;

            SET @O_Num = @Id_Rol;
            SET @O_Msg = 'Rol actualizado correctamente.';
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
        IF @Id_Rol IS NULL OR @Id_Modificador IS NULL
        BEGIN
            SET @O_Msg = 'Id_Rol e Id_Modificador requeridos.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            UPDATE Cls_Roles
            SET Activo = 0,
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = @Id_Modificador
            WHERE Id_Rol = @Id_Rol;

            SET @O_Num = @Id_Rol;
            SET @O_Msg = 'Rol inactivado correctamente.';
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
            Id_Rol,
            Nombre_Rol,
            Descripcion,
            Activo,
            CASE WHEN Activo = 1 THEN 'Sí' ELSE 'No' END AS EstadoActivo,
            Fecha_Creacion,
            Fecha_Modificacion,
            Id_Creador,
            Id_Modificador
        FROM Cls_Roles;

        SET @O_Msg = 'Listado de roles.';
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
                Id_Rol,
                Nombre_Rol,
                Descripcion,
                Activo,
                CASE WHEN Activo = 1 THEN 'Sí' ELSE 'No' END AS EstadoActivo,
                Fecha_Creacion,
                Fecha_Modificacion,
                Id_Creador,
                Id_Modificador
            FROM Cls_Roles
            WHERE Nombre_Rol LIKE '%' + @Filtro + '%'
               OR CAST(Id_Rol AS VARCHAR) = @Filtro;

            IF @@ROWCOUNT > 0
            BEGIN
                SET @O_Msg = 'Consulta con filtro realizada.';
                SET @O_Num = 0;
            END
            ELSE
            BEGIN
                SET @O_Msg = 'No se encontraron roles con ese filtro.';
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