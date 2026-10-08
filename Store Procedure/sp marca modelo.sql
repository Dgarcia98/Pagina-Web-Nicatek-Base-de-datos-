USE NicaTek;
GO

CREATE OR ALTER PROC sp_Tbl_Marca_Modelo
    @Mode VARCHAR(3) = NULL,
    @O_Msg VARCHAR(255) = NULL OUTPUT,
    @O_Num INT = NULL OUTPUT,
    @Id_Marca_Modelo INT = NULL,
    @Id_Marca INT = NULL,
    @Id_Modelo INT = NULL,
    @Id_Estado INT = NULL,
    @Id_Creador INT = NULL,
    @Id_Modificador INT = NULL,
    @Filtro VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Mode = 'INS'
    BEGIN
        IF @Id_Marca IS NULL OR @Id_Modelo IS NULL OR @Id_Estado IS NULL OR @Id_Creador IS NULL OR @Id_Modificador IS NULL
        BEGIN
            SET @O_Msg = 'Faltan campos obligatorios.';
            SET @O_Num = -1;
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Cls_Marca WHERE Id_Marca = @Id_Marca)
        BEGIN
            SET @O_Msg = 'La marca especificada no existe.';
            SET @O_Num = -1;
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Cls_Modelo WHERE Id_Modelo = @Id_Modelo)
        BEGIN
            SET @O_Msg = 'El modelo especificado no existe.';
            SET @O_Num = -1;
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM Tbl_Marca_Modelo WHERE Id_Marca = @Id_Marca AND Id_Modelo = @Id_Modelo)
        BEGIN
            SET @O_Msg = 'Ya existe esa relación Marca/Modelo.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            INSERT INTO Tbl_Marca_Modelo (
                Id_Marca, Id_Modelo, Id_Estado,
                Fecha_Creacion, Fecha_Modificacion,
                Id_Creador, Id_Modificador
            )
            VALUES (
                @Id_Marca, @Id_Modelo, @Id_Estado,
                GETDATE(), GETDATE(),
                @Id_Creador, @Id_Modificador
            );

            SET @O_Num = SCOPE_IDENTITY();
            SET @O_Msg = 'Marca/Modelo registrada correctamente.';
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
        IF @Id_Marca_Modelo IS NULL
        BEGIN
            SET @O_Msg = 'Id_Marca_Modelo requerido para actualizar.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            UPDATE Tbl_Marca_Modelo
            SET Id_Marca = COALESCE(@Id_Marca, Id_Marca),
                Id_Modelo = COALESCE(@Id_Modelo, Id_Modelo),
                Id_Estado = COALESCE(@Id_Estado, Id_Estado),
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = COALESCE(@Id_Modificador, Id_Modificador)
            WHERE Id_Marca_Modelo = @Id_Marca_Modelo;

            SET @O_Num = @Id_Marca_Modelo;
            SET @O_Msg = 'Marca/Modelo actualizada correctamente.';
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
        IF @Id_Marca_Modelo IS NULL OR @Id_Modificador IS NULL
        BEGIN
            SET @O_Msg = 'Id_Marca_Modelo e Id_Modificador requeridos.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            UPDATE Tbl_Marca_Modelo
            SET Id_Estado = 2,
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = @Id_Modificador
            WHERE Id_Marca_Modelo = @Id_Marca_Modelo;

            SET @O_Num = @Id_Marca_Modelo;
            SET @O_Msg = 'Marca/Modelo inactivada correctamente.';
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
            mm.Id_Marca_Modelo,
            mm.Id_Marca,
            m.Nombre_Marca,
            mm.Id_Modelo,
            mo.Nombre_Modelo,
            mm.Id_Estado,
            e.Estado,
            mm.Fecha_Creacion,
            mm.Fecha_Modificacion
        FROM Tbl_Marca_Modelo mm
        JOIN Cls_Marca m ON mm.Id_Marca = m.Id_Marca
        JOIN Cls_Modelo mo ON mm.Id_Modelo = mo.Id_Modelo
        JOIN Cls_Estados e ON mm.Id_Estado = e.Id_Estado;

        SET @O_Msg = 'Listado de combinaciones Marca/Modelo.';
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
                mm.Id_Marca_Modelo,
                mm.Id_Marca,
                m.Nombre_Marca,
                mm.Id_Modelo,
                mo.Nombre_Modelo,
                mm.Id_Estado,
                e.Estado,
                mm.Fecha_Creacion,
                mm.Fecha_Modificacion
            FROM Tbl_Marca_Modelo mm
            JOIN Cls_Marca m ON mm.Id_Marca = m.Id_Marca
            JOIN Cls_Modelo mo ON mm.Id_Modelo = mo.Id_Modelo
            JOIN Cls_Estados e ON mm.Id_Estado = e.Id_Estado
            WHERE m.Nombre_Marca LIKE '%' + @Filtro + '%'
               OR mo.Nombre_Modelo LIKE '%' + @Filtro + '%'
               OR e.Estado LIKE '%' + @Filtro + '%'
               OR CAST(mm.Id_Marca_Modelo AS VARCHAR) = @Filtro;

            IF @@ROWCOUNT > 0
            BEGIN
                SET @O_Msg = 'Consulta con filtro realizada.';
                SET @O_Num = 0;
            END
            ELSE
            BEGIN
                SET @O_Msg = 'No se encontraron combinaciones con ese filtro.';
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