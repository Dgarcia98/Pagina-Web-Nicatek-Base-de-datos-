USE NicaTek;
GO

CREATE OR ALTER PROC sp_Cls_Marca
    @Mode VARCHAR(3) = NULL,
    @O_Msg VARCHAR(255) = NULL OUTPUT,
    @O_Num INT = NULL OUTPUT,
    @Id_Marca INT = NULL,
    @Nombre_Marca VARCHAR(100) = NULL,
    @Id_Estado INT = NULL,
    @Id_Creador INT = NULL,
    @Id_Modificador INT = NULL,
    @Filtro VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- INSERTAR
    IF @Mode = 'INS'
    BEGIN
        IF @Nombre_Marca IS NULL OR @Id_Estado IS NULL OR @Id_Creador IS NULL OR @Id_Modificador IS NULL
        BEGIN
            SET @O_Msg = 'Faltan campos obligatorios.';
            SET @O_Num = -1;
            RETURN;
        END

        -- Validar que no exista el nombre
        IF EXISTS (SELECT 1 FROM Cls_Marca WHERE Nombre_Marca = @Nombre_Marca)
        BEGIN
            SET @O_Msg = 'Ya existe una marca con ese nombre.';
            SET @O_Num = -1;
            RETURN;
        END

        -- Validar estado
        IF NOT EXISTS (SELECT 1 FROM Cls_Estados WHERE Id_Estado = @Id_Estado)
        BEGIN
            SET @O_Msg = 'El estado especificado no existe.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            INSERT INTO Cls_Marca (
                Nombre_Marca, Id_Estado,
                Fecha_Creacion, Fecha_Modificacion,
                Id_Creador, Id_Modificador
            )
            VALUES (
                @Nombre_Marca, @Id_Estado,
                GETDATE(), GETDATE(),
                @Id_Creador, @Id_Modificador
            );

            SET @O_Num = SCOPE_IDENTITY();
            SET @O_Msg = 'Marca registrada correctamente.';
            COMMIT;
        END TRY
        BEGIN CATCH
            ROLLBACK;
            SET @O_Msg = ERROR_MESSAGE();
            SET @O_Num = ERROR_NUMBER();
        END CATCH
    END

    -- ACTUALIZAR
    ELSE IF @Mode = 'UPD'
    BEGIN
        IF @Id_Marca IS NULL
        BEGIN
            SET @O_Msg = 'Id_Marca requerido para actualizar.';
            SET @O_Num = -1;
            RETURN;
        END

        -- Opcional: Validar que el nuevo nombre no duplique otra marca existente
        IF @Nombre_Marca IS NOT NULL AND EXISTS (SELECT 1 FROM Cls_Marca WHERE Nombre_Marca = @Nombre_Marca AND Id_Marca <> @Id_Marca)
        BEGIN
             SET @O_Msg = 'El nombre de la marca ya está en uso por otro registro.';
             SET @O_Num = -1;
             RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            UPDATE Cls_Marca
            SET Nombre_Marca = COALESCE(@Nombre_Marca, Nombre_Marca),
                Id_Estado = COALESCE(@Id_Estado, Id_Estado),
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = COALESCE(@Id_Modificador, Id_Modificador)
            WHERE Id_Marca = @Id_Marca;

            SET @O_Num = @Id_Marca;
            SET @O_Msg = 'Marca actualizada correctamente.';
            COMMIT;
        END TRY
        BEGIN CATCH
            ROLLBACK;
            SET @O_Msg = ERROR_MESSAGE();
            SET @O_Num = ERROR_NUMBER();
        END CATCH
    END

    -- INACTIVAR (Borrado Lógico)
    ELSE IF @Mode = 'DEL'
    BEGIN
        IF @Id_Marca IS NULL OR @Id_Modificador IS NULL
        BEGIN
            SET @O_Msg = 'Id_Marca e Id_Modificador requeridos.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            UPDATE Cls_Marca
            SET Id_Estado = 2, -- Inactivo
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = @Id_Modificador
            WHERE Id_Marca = @Id_Marca;

            SET @O_Num = @Id_Marca;
            SET @O_Msg = 'Marca inactivada correctamente.';
            COMMIT;
        END TRY
        BEGIN CATCH
            ROLLBACK;
            SET @O_Msg = ERROR_MESSAGE();
            SET @O_Num = ERROR_NUMBER();
        END CATCH
    END

    -- LISTAR
    ELSE IF @Mode = 'LST'
    BEGIN
        SELECT 
            m.Id_Marca,
            m.Nombre_Marca,
            m.Id_Estado,
            e.Estado,
            m.Fecha_Creacion,
            m.Fecha_Modificacion,
            m.Id_Creador,
            m.Id_Modificador
        FROM Cls_Marca m
        JOIN Cls_Estados e ON m.Id_Estado = e.Id_Estado;

        SET @O_Msg = 'Listado de marcas.';
        SET @O_Num = 0;
    END

    -- FILTRAR
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
                m.Id_Marca,
                m.Nombre_Marca,
                m.Id_Estado,
                e.Estado,
                m.Fecha_Creacion,
                m.Fecha_Modificacion,
                m.Id_Creador,
                m.Id_Modificador
            FROM Cls_Marca m
            JOIN Cls_Estados e ON m.Id_Estado = e.Id_Estado
            WHERE m.Nombre_Marca LIKE '%' + @Filtro + '%'
               OR CAST(m.Id_Marca AS VARCHAR) = @Filtro
               OR e.Estado LIKE '%' + @Filtro + '%';

            IF @@ROWCOUNT > 0
            BEGIN
                SET @O_Msg = 'Consulta con filtro realizada.';
                SET @O_Num = 0;
            END
            ELSE
            BEGIN
                SET @O_Msg = 'No se encontraron marcas con ese filtro.';
                SET @O_Num = 0;
            END
        END
    END

    -- MODO NO RECONOCIDO
    ELSE
    BEGIN
        SET @O_Msg = 'Modo no reconocido.';
        SET @O_Num = -1;
    END
END
GO