USE NicaTek;
GO

CREATE OR ALTER PROC sp_Tbl_Roles_Permisos
    @Mode VARCHAR(3) = NULL,
    @O_Msg VARCHAR(255) = NULL OUTPUT,
    @O_Num INT = NULL OUTPUT,
    
    @Id_Rol_Permiso INT = NULL,
    @Id_Rol INT = NULL,
    @Id_Permiso INT = NULL,
    @Activo BIT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- ASIGNAR PERMISO A UN ROL (Insertar o Reactivar)
    IF @Mode = 'INS'
    BEGIN
        IF @Id_Rol IS NULL OR @Id_Permiso IS NULL
        BEGIN
            SET @O_Msg = 'Faltan campos obligatorios (Id_Rol, Id_Permiso).';
            SET @O_Num = -1;
            RETURN;
        END

        -- Verificar si la relación ya existe
        IF EXISTS (SELECT 1 FROM Tbl_Roles_Permisos WHERE Id_Rol = @Id_Rol AND Id_Permiso = @Id_Permiso)
        BEGIN
            -- Si ya existe, nos aseguramos de que esté activo
            BEGIN TRY
                BEGIN TRAN;
                UPDATE Tbl_Roles_Permisos 
                SET Activo = 1 
                WHERE Id_Rol = @Id_Rol AND Id_Permiso = @Id_Permiso;
                
                SET @O_Msg = 'El permiso fue asignado (reactivado) correctamente.';
                SET @O_Num = 1;
                COMMIT;
                RETURN;
            END TRY
            BEGIN CATCH
                ROLLBACK;
                SET @O_Msg = ERROR_MESSAGE();
                SET @O_Num = ERROR_NUMBER();
                RETURN;
            END CATCH
        END

        -- Si no existe, lo insertamos
        BEGIN TRY
            BEGIN TRAN;
            INSERT INTO Tbl_Roles_Permisos (Id_Rol, Id_Permiso, Activo)
            VALUES (@Id_Rol, @Id_Permiso, ISNULL(@Activo, 1));
            
            SET @O_Num = SCOPE_IDENTITY();
            SET @O_Msg = 'Permiso asignado al rol correctamente.';
            COMMIT;
        END TRY
        BEGIN CATCH
            ROLLBACK;
            SET @O_Msg = ERROR_MESSAGE();
            SET @O_Num = ERROR_NUMBER();
        END CATCH
    END

    -- QUITAR PERMISO A UN ROL (Borrado lógico)
    ELSE IF @Mode = 'DEL'
    BEGIN
        IF @Id_Rol IS NULL OR @Id_Permiso IS NULL
        BEGIN
            SET @O_Msg = 'Se requieren Id_Rol e Id_Permiso para quitar el acceso.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;
            
            -- Inactivamos el permiso para ese rol
            UPDATE Tbl_Roles_Permisos 
            SET Activo = 0 
            WHERE Id_Rol = @Id_Rol AND Id_Permiso = @Id_Permiso;
            
            SET @O_Msg = 'Permiso removido del rol correctamente.';
            SET @O_Num = 0;
            COMMIT;
        END TRY
        BEGIN CATCH
            ROLLBACK;
            SET @O_Msg = ERROR_MESSAGE();
            SET @O_Num = ERROR_NUMBER();
        END CATCH
    END

    -- LISTAR PERMISOS ACTIVOS DE UN ROL
    ELSE IF @Mode = 'LST'
    BEGIN
        -- Trae todos los permisos que un rol específico tiene asignados
        SELECT 
            rp.Id_Rol_Permiso,
            rp.Id_Rol,
            r.Nombre_Rol,
            rp.Id_Permiso,
            p.Nombre_Permiso,
            p.Codigo_Permiso,
            p.Descripcion AS Descripcion_Permiso,
            rp.Activo
        FROM Tbl_Roles_Permisos rp
        INNER JOIN Cls_Roles r ON rp.Id_Rol = r.Id_Rol
        INNER JOIN Cls_Permisos p ON rp.Id_Permiso = p.Id_Permiso
        WHERE (@Id_Rol IS NULL OR rp.Id_Rol = @Id_Rol) 
          AND rp.Activo = 1
          AND p.Id_Estado = 1; -- Validamos que el permiso base también esté activo en su catálogo

        SET @O_Msg = 'Consulta de permisos por rol realizada.';
        SET @O_Num = 0;
    END

    ELSE
    BEGIN
        SET @O_Msg = 'Modo no reconocido.';
        SET @O_Num = -1;
    END
END
GO