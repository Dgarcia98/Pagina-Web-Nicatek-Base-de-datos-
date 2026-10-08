CREATE OR ALTER PROC spTblCategoria
    @Mode VARCHAR(3) = NULL,
    @O_Msg VARCHAR(255) = NULL OUTPUT,
    @O_Num INT = NULL OUTPUT,
    @Id_Categoria INT = NULL,
    @Nombre VARCHAR(50) = NULL,
    @Id_Estado INT = NULL,
    @Id_Creador INT = NULL,
    @Id_Modificador INT = NULL,
    @Filtro VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Mode = 'INS'
    BEGIN
        IF @Nombre IS NULL OR @Id_Estado IS NULL OR @Id_Creador IS NULL OR @Id_Modificador IS NULL
        BEGIN
            SET @O_Msg = 'Faltan campos obligatorios.';
            SET @O_Num = -1;
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM Tbl_Categoria WHERE Nombre = @Nombre AND Id_Estado = 1)
        BEGIN
            SET @O_Msg = 'Ya existe una categoría activa con ese nombre.';
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

            INSERT INTO Tbl_Categoria (
                Nombre, Fecha_Creacion, Fecha_Modificacion,
                Id_Estado, Id_Creador, Id_Modificador
            )
            VALUES (
                @Nombre, GETDATE(), GETDATE(),
                @Id_Estado, @Id_Creador, @Id_Modificador
            );

            SET @O_Num = SCOPE_IDENTITY();
            SET @O_Msg = 'Categoría registrada correctamente.';
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
        IF @Id_Categoria IS NULL
        BEGIN
            SET @O_Msg = 'Id_Categoria requerido para actualizar.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            UPDATE Tbl_Categoria
            SET Nombre = COALESCE(@Nombre, Nombre),
                Id_Estado = COALESCE(@Id_Estado, Id_Estado),
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = COALESCE(@Id_Modificador, Id_Modificador)
            WHERE Id_Categoria = @Id_Categoria;

            SET @O_Num = @Id_Categoria;
            SET @O_Msg = 'Categoría actualizada correctamente.';
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
        IF @Id_Categoria IS NULL OR @Id_Modificador IS NULL
        BEGIN
            SET @O_Msg = 'Id_Categoria e Id_Modificador requeridos para eliminar.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            UPDATE Tbl_Categoria
            SET Id_Estado = 2, 
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = @Id_Modificador
            WHERE Id_Categoria = @Id_Categoria;

            SET @O_Num = @Id_Categoria;
            SET @O_Msg = 'Categoría eliminada (inactivada) correctamente.';
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
            c.Id_Categoria,
            c.Nombre,
            c.Fecha_Creacion,
            c.Fecha_Modificacion,
            c.Id_Estado,
            e.Estado,
            c.Id_Creador,
            c.Id_Modificador
        FROM Tbl_Categoria c
        JOIN Cls_Estados e ON c.Id_Estado = e.Id_Estado
        --WHERE c.Id_Estado = 1;

        SET @O_Msg = 'Listado de categorías.';
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
            c.Id_Categoria,
            c.Nombre,
            c.Fecha_Creacion,
            c.Fecha_Modificacion,
            c.Id_Estado,
            e.Estado,
            c.Id_Creador,
            c.Id_Modificador
        FROM Tbl_Categoria c
        JOIN Cls_Estados e ON c.Id_Estado = e.Id_Estado
        WHERE (c.Nombre LIKE '%' + @Filtro + '%'
            OR CAST(c.Id_Categoria AS VARCHAR) = @Filtro
            OR e.Estado LIKE '%' + @Filtro + '%')
           -- AND c.Id_Estado = 1;

        SET @O_Msg = 'Consulta con filtro realizada.';
        SET @O_Num = 0;
    END

    ELSE
    BEGIN
        SET @O_Msg = 'Modo no reconocido.';
        SET @O_Num = -1;
    END
END
GO