CREATE OR ALTER PROCEDURE SP_Obtener_Permisos_Usuario
    @Id_Usuario INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Este query cruza 4 tablas para llegar a la verdad:
    -- Usuario -> Su Rol -> Los Permisos del Rol -> El Código del Permiso
    SELECT 
        P.Codigo_Permiso,  -- Ej: 'INV_DELETE', 'USR_CREATE'
        P.Nombre_Permiso
    FROM Tbl_Usuarios U
    INNER JOIN Cls_Roles R ON U.Id_Rol = R.Id_Rol
    INNER JOIN Tbl_Roles_Permisos RP ON R.Id_Rol = RP.Id_Rol
    INNER JOIN Cls_Permisos P ON RP.Id_Permiso = P.Id_Permiso
    WHERE U.Id_Usuario = @Id_Usuario
      AND U.Id_Estado = 1    -- Usuario Activo
      AND RP.Activo = 1      -- Asignación Activa
      AND P.Id_Estado = 1;   -- Permiso Global Activo
END
GO