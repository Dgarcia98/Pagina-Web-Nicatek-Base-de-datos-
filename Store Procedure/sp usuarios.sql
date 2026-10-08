CREATE OR ALTER PROC spTblUsuarios
    @Mode VARCHAR(10) = NULL,
    @O_Msg VARCHAR(255) = NULL OUTPUT,
    @O_Num INT = NULL OUTPUT,
    @Id_Usuario INT = NULL,
    @Nombre_Usuario VARCHAR(100) = NULL,
    @Contrasena VARCHAR(255) = NULL,
    @Id_Persona INT = NULL,
    @Id_Rol INT = NULL,
    @Id_Estado INT = NULL,
    @Id_Creador INT = NULL,
    @Id_Modificador INT = NULL,
    @Filtro VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Mode = 'INS'
    BEGIN
        IF @Nombre_Usuario IS NULL OR @Contrasena IS NULL OR @Id_Persona IS NULL OR @Id_Rol IS NULL OR @Id_Estado IS NULL
        BEGIN
            SET @O_Msg = 'Faltan campos obligatorios.';
            SET @O_Num = -1;
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM Tbl_Usuarios WHERE Nombre_Usuario = @Nombre_Usuario)
        BEGIN
            SET @O_Msg = 'Ya existe un usuario con ese nombre.';
            SET @O_Num = -1;
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM Tbl_Usuarios WHERE Id_Persona = @Id_Persona)
        BEGIN
            SET @O_Msg = 'Error: Esta persona ya tiene un usuario asignado en el sistema.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;
            INSERT INTO Tbl_Usuarios (Nombre_Usuario, Contrasena, Id_Persona, Id_Rol, Id_Estado, Fecha_Creacion, Id_Creador, Fecha_Modificacion, Id_Modificador)
            VALUES (@Nombre_Usuario, @Contrasena, @Id_Persona, @Id_Rol, @Id_Estado, GETDATE(), @Id_Creador, GETDATE(), @Id_Modificador);
            
            SET @O_Num = SCOPE_IDENTITY();
            SET @O_Msg = 'Usuario registrado correctamente.';
            COMMIT;
        END TRY
        BEGIN CATCH
            ROLLBACK;
            SET @O_Msg = ERROR_MESSAGE(); SET @O_Num = ERROR_NUMBER();
        END CATCH
    END

    ELSE IF @Mode = 'UPD'
    BEGIN
        IF @Id_Usuario IS NULL
        BEGIN
            SET @O_Msg = 'ID requerido.'; SET @O_Num = -1; RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;
            UPDATE Tbl_Usuarios
            SET Nombre_Usuario = COALESCE(@Nombre_Usuario, Nombre_Usuario),
                Contrasena = COALESCE(@Contrasena, Contrasena),
                Id_Persona = COALESCE(@Id_Persona, Id_Persona),
                Id_Rol = COALESCE(@Id_Rol, Id_Rol),
                Id_Estado = COALESCE(@Id_Estado, Id_Estado),
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = @Id_Modificador
            WHERE Id_Usuario = @Id_Usuario;
            
            SET @O_Num = @Id_Usuario;
            SET @O_Msg = 'Usuario actualizado.';
            COMMIT;
        END TRY
        BEGIN CATCH
            ROLLBACK;
            SET @O_Msg = ERROR_MESSAGE(); SET @O_Num = ERROR_NUMBER();
        END CATCH
    END

    ELSE IF @Mode = 'DEL'
    BEGIN
        IF @Id_Usuario IS NULL OR @Id_Modificador IS NULL
        BEGIN
            SET @O_Msg = 'Id_Usuario e Id_Modificador requeridos.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;
            UPDATE Tbl_Usuarios
            SET Id_Estado = 2,
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = @Id_Modificador
            WHERE Id_Usuario = @Id_Usuario;

            SET @O_Num = @Id_Usuario;
            SET @O_Msg = 'Usuario inactivado correctamente.';
            COMMIT;
        END TRY
        BEGIN CATCH
            ROLLBACK;
            SET @O_Msg = ERROR_MESSAGE(); SET @O_Num = ERROR_NUMBER();
        END CATCH
    END

    ELSE IF @Mode = 'LST'
    BEGIN
        SELECT 
            u.Id_Usuario, 
            u.Nombre_Usuario, 
            u.Id_Persona,
            (p.Primer_Nombre + ' ' + p.Primer_Apellido) AS Nombre_Persona,
            u.Id_Rol, 
            r.Nombre_Rol,
            u.Id_Estado, 
            e.Estado,
            u.Fecha_Ultimo_Acceso, 
            u.Fecha_Creacion, 
            u.Id_Creador,
            u.Fecha_Modificacion,
            u.Id_Modificador
        FROM Tbl_Usuarios u
        INNER JOIN Tbl_Datos_Personales p ON u.Id_Persona = p.Id_Persona
        INNER JOIN Cls_Roles r ON u.Id_Rol = r.Id_Rol
        INNER JOIN Cls_Estados e ON u.Id_Estado = e.Id_Estado;
     

        SET @O_Msg = 'Listado exitoso.'; SET @O_Num = 0;
    END

    ELSE IF @Mode = 'FIL'
    BEGIN
        SELECT 
            u.Id_Usuario, 
            u.Nombre_Usuario, 
            u.Id_Persona,
            (p.Primer_Nombre + ' ' + p.Primer_Apellido) AS Nombre_Persona,
            u.Id_Rol, 
            r.Nombre_Rol,
            u.Id_Estado, 
            e.Estado,
            u.Fecha_Ultimo_Acceso, 
            u.Fecha_Creacion, 
            u.Id_Creador,
            u.Fecha_Modificacion,
            u.Id_Modificador
        FROM Tbl_Usuarios u
        INNER JOIN Tbl_Datos_Personales p ON u.Id_Persona = p.Id_Persona
        INNER JOIN Cls_Roles r ON u.Id_Rol = r.Id_Rol
        INNER JOIN Cls_Estados e ON u.Id_Estado = e.Id_Estado
        WHERE (u.Nombre_Usuario LIKE '%' + @Filtro + '%' OR p.DNI LIKE '%' + @Filtro + '%');
       

        SET @O_Msg = 'Consulta filtrada.'; SET @O_Num = 0;
    END
END