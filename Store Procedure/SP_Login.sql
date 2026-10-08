CREATE OR ALTER PROC spLogin
    @Usuario VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    IF @Usuario IS NULL OR LTRIM(RTRIM(@Usuario)) = '' RETURN;

    -- Actualizar fecha de último acceso al momento del login
    UPDATE Tbl_Usuarios
    SET Fecha_Ultimo_Acceso = GETDATE()
    WHERE Nombre_Usuario = @Usuario
      AND Id_Estado = 1;

    SELECT 
        u.Id_Usuario, 
        u.Nombre_Usuario, 
        u.Contrasena,
        u.Id_Rol,
        r.Nombre_Rol,
        u.Id_Persona,
        dp.Primer_Nombre,
        dp.Primer_Apellido,
        dp.DNI,
        (ISNULL(dp.Primer_Nombre, '') + ' ' + ISNULL(dp.Primer_Apellido, '')) AS Nombre_Completo,
        u.Fecha_Ultimo_Acceso
    FROM Tbl_Usuarios u
    INNER JOIN Cls_Roles r ON u.Id_Rol = r.Id_Rol
    INNER JOIN Tbl_Datos_Personales dp ON u.Id_Persona = dp.Id_Persona
    WHERE u.Nombre_Usuario = @Usuario 
      AND u.Id_Estado = 1; 
END
GO