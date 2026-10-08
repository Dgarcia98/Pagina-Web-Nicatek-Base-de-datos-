USE NicaTek;
GO

CREATE OR ALTER PROC sp_Cls_Permisos
    @Mode VARCHAR(3) = NULL,
    @O_Msg VARCHAR(255) = NULL OUTPUT,
    @O_Num INT = NULL OUTPUT,
    
    @Id_Permiso INT = NULL,
    @Nombre_Permiso VARCHAR(100) = NULL,
    @Codigo_Permiso VARCHAR(50) = NULL,
    @Descripcion VARCHAR(255) = NULL,
    @Id_Estado INT = NULL,
    @Filtro VARCHAR(100) = NULL -- <-- Agregamos el parámetro para el buscador
AS
BEGIN
    SET NOCOUNT ON;

    -- REGISTRAR NUEVO PERMISO
    IF @Mode = 'INS'
    BEGIN
        IF EXISTS (SELECT 1 FROM Cls_Permisos WHERE Codigo_Permiso = @Codigo_Permiso)
        BEGIN
            SET @O_Msg = 'El código de permiso ya existe en el sistema.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            INSERT INTO Cls_Permisos (Nombre_Permiso, Codigo_Permiso, Descripcion, Id_Estado)
            VALUES (@Nombre_Permiso, @Codigo_Permiso, @Descripcion, ISNULL(@Id_Estado, 1));
            
            SET @O_Num = SCOPE_IDENTITY();
            SET @O_Msg = 'Permiso registrado correctamente.';
        END TRY
        BEGIN CATCH
            SET @O_Msg = ERROR_MESSAGE();
            SET @O_Num = ERROR_NUMBER();
        END CATCH
    END

    -- ACTUALIZAR PERMISO EXISTENTE
    ELSE IF @Mode = 'UPD'
    BEGIN
        IF @Id_Permiso IS NULL
        BEGIN
            SET @O_Msg = 'Se requiere el ID del permiso para actualizar.';
            SET @O_Num = -1;
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM Cls_Permisos WHERE Codigo_Permiso = @Codigo_Permiso AND Id_Permiso <> @Id_Permiso)
        BEGIN
            SET @O_Msg = 'El código de permiso ingresado ya está en uso por otro registro.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            UPDATE Cls_Permisos
            SET Nombre_Permiso = ISNULL(@Nombre_Permiso, Nombre_Permiso),
                Codigo_Permiso = ISNULL(@Codigo_Permiso, Codigo_Permiso),
                Descripcion = ISNULL(@Descripcion, Descripcion),
                Id_Estado = ISNULL(@Id_Estado, Id_Estado)
            WHERE Id_Permiso = @Id_Permiso;
            
            SET @O_Num = @Id_Permiso;
            SET @O_Msg = 'Permiso actualizado correctamente.';
        END TRY
        BEGIN CATCH
            SET @O_Msg = ERROR_MESSAGE();
            SET @O_Num = ERROR_NUMBER();
        END CATCH
    END

    -- ELIMINAR LÓGICAMENTE (Inactivar)
    ELSE IF @Mode = 'DEL'
    BEGIN
        IF @Id_Permiso IS NULL
        BEGIN
            SET @O_Msg = 'Se requiere el ID del permiso para inactivar.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            UPDATE Cls_Permisos
            SET Id_Estado = 0 
            WHERE Id_Permiso = @Id_Permiso;
            
            SET @O_Num = @Id_Permiso;
            SET @O_Msg = 'Permiso inactivado correctamente.';
        END TRY
        BEGIN CATCH
            SET @O_Msg = ERROR_MESSAGE();
            SET @O_Num = ERROR_NUMBER();
        END CATCH
    END

    -- LISTAR TODOS LOS PERMISOS
    ELSE IF @Mode = 'LST'
    BEGIN
        SELECT 
            Id_Permiso,
            Nombre_Permiso,
            Codigo_Permiso,
            Descripcion,
            Id_Estado
        FROM Cls_Permisos
        ORDER BY Nombre_Permiso ASC;

        SET @O_Msg = 'Consulta de permisos realizada.';
        SET @O_Num = 0;
    END

    -- OBTENER PERMISO POR ID
    ELSE IF @Mode = 'GET'
    BEGIN
        SELECT 
            Id_Permiso,
            Nombre_Permiso,
            Codigo_Permiso,
            Descripcion,
            Id_Estado
        FROM Cls_Permisos
        WHERE Id_Permiso = @Id_Permiso;

        SET @O_Msg = 'Consulta por ID realizada.';
        SET @O_Num = 0;
    END

    -- FILTRAR PERMISOS POR TEXTO (Nuevo bloque)
    ELSE IF @Mode = 'FLT'
    BEGIN
        SELECT 
            Id_Permiso,
            Nombre_Permiso,
            Codigo_Permiso,
            Descripcion,
            Id_Estado
        FROM Cls_Permisos
        WHERE Nombre_Permiso LIKE '%' + ISNULL(@Filtro, '') + '%'
           OR Codigo_Permiso LIKE '%' + ISNULL(@Filtro, '') + '%'
           OR Descripcion LIKE '%' + ISNULL(@Filtro, '') + '%'
        ORDER BY Nombre_Permiso ASC;

        SET @O_Msg = 'Búsqueda de permisos realizada.';
        SET @O_Num = 0;
    END

    ELSE
    BEGIN
        SET @O_Msg = 'Modo no reconocido.';
        SET @O_Num = -1;
    END
END
GO