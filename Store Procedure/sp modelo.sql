USE NicaTek;
GO

CREATE OR ALTER PROC sp_Cls_Modelo
    @Mode VARCHAR(3) = NULL,
    @O_Msg VARCHAR(255) = NULL OUTPUT,
    @O_Num INT = NULL OUTPUT,
    @Id_Modelo INT = NULL,
    @Nombre_Modelo VARCHAR(100) = NULL,
    @Id_Estado INT = NULL,
    @Id_Creador INT = NULL,
    @Id_Modificador INT = NULL,
    @Filtro VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Mode = 'INS'
    BEGIN
        IF @Nombre_Modelo IS NULL OR @Id_Estado IS NULL OR @Id_Creador IS NULL OR @Id_Modificador IS NULL
        BEGIN
            SET @O_Msg = 'Faltan campos obligatorios.';
            SET @O_Num = -1;
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM Cls_Modelo WHERE Nombre_Modelo = @Nombre_Modelo)
        BEGIN
            SET @O_Msg = 'Ya existe un modelo con ese nombre.';
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

            INSERT INTO Cls_Modelo (
                Nombre_Modelo, Id_Estado,
                Fecha_Creacion, Fecha_Modificacion,
                Id_Creador, Id_Modificador
            )
            VALUES (
                @Nombre_Modelo, @Id_Estado,
                GETDATE(), GETDATE(),
                @Id_Creador, @Id_Modificador
            );

            SET @O_Num = SCOPE_IDENTITY();
            SET @O_Msg = 'Modelo registrado correctamente.';
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
        IF @Id_Modelo IS NULL
        BEGIN
            SET @O_Msg = 'Id_Modelo requerido para actualizar.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            UPDATE Cls_Modelo
            SET Nombre_Modelo = COALESCE(@Nombre_Modelo, Nombre_Modelo),
                Id_Estado = COALESCE(@Id_Estado, Id_Estado),
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = COALESCE(@Id_Modificador, Id_Modificador)
            WHERE Id_Modelo = @Id_Modelo;

            SET @O_Num = @Id_Modelo;
            SET @O_Msg = 'Modelo actualizado correctamente.';
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
        IF @Id_Modelo IS NULL OR @Id_Modificador IS NULL
        BEGIN
            SET @O_Msg = 'Id_Modelo e Id_Modificador requeridos.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            UPDATE Cls_Modelo
            SET Id_Estado = 2, -- Estado Inactivo
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = @Id_Modificador
            WHERE Id_Modelo = @Id_Modelo;

            SET @O_Num = @Id_Modelo;
            SET @O_Msg = 'Modelo inactivado correctamente.';
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
            m.Id_Modelo,
            m.Nombre_Modelo,
            m.Id_Estado,
            e.Estado,
            m.Fecha_Creacion,
            m.Fecha_Modificacion,
            m.Id_Creador,
            m.Id_Modificador
        FROM Cls_Modelo m
        JOIN Cls_Estados e ON m.Id_Estado = e.Id_Estado;

        SET @O_Msg = 'Listado de modelos.';
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
                m.Id_Modelo,
                m.Nombre_Modelo,
                m.Id_Estado,
                e.Estado,
                m.Fecha_Creacion,
                m.Fecha_Modificacion,
                m.Id_Creador,
                m.Id_Modificador
            FROM Cls_Modelo m
            JOIN Cls_Estados e ON m.Id_Estado = e.Id_Estado
            WHERE m.Nombre_Modelo LIKE '%' + @Filtro + '%'
               OR CAST(m.Id_Modelo AS VARCHAR) = @Filtro
               OR e.Estado LIKE '%' + @Filtro + '%';

            IF @@ROWCOUNT > 0
            BEGIN
                SET @O_Msg = 'Consulta con filtro realizada.';
                SET @O_Num = 0;
            END
            ELSE
            BEGIN
                SET @O_Msg = 'No se encontraron modelos con ese filtro.';
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