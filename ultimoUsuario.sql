USE NicaTek;
GO

--Trigger: prevenir eliminar/desactivar al último usuario activo
CREATE OR ALTER TRIGGER tr_Proteger_Ultimo_Usuario
ON Tbl_Usuarios
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- Contar usuarios activos DESPUÉS de la operación
    DECLARE @ActivosRestantes INT;
    SELECT @ActivosRestantes = COUNT(*)
    FROM Tbl_Usuarios
    WHERE Id_Estado = 1;

    IF @ActivosRestantes = 0
    BEGIN
        RAISERROR('No se puede desactivar o eliminar al último usuario activo del sistema.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END

    -- También proteger al último administrador activo
    DECLARE @AdminsRestantes INT;
    SELECT @AdminsRestantes = COUNT(*)
    FROM Tbl_Usuarios u
    INNER JOIN Cls_Roles r ON u.Id_Rol = r.Id_Rol
    WHERE u.Id_Estado = 1
      AND r.Nombre_Rol = 'Administrador';

    IF @AdminsRestantes = 0
    BEGIN
        RAISERROR('No se puede desactivar o eliminar al último administrador activo del sistema.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END
GO