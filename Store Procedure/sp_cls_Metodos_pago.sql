USE NicaTek;
GO

CREATE OR ALTER PROC spClsMetodosPago
    @Mode VARCHAR(3) = NULL,
    @O_Msg VARCHAR(255) = NULL OUTPUT,
    @O_Num INT = NULL OUTPUT,
    @Id_Metodo_Pago INT = NULL,
    @Descripcion VARCHAR(50) = NULL,
    @Id_Estado INT = NULL,
    @Id_Creador INT = NULL,
    @Id_Modificador INT = NULL,
    @Filtro VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Mode = 'INS'
    BEGIN
        IF @Descripcion IS NULL OR @Id_Estado IS NULL
        BEGIN
            SET @O_Msg = 'Faltan campos obligatorios (Descripcion, Estado).';
            SET @O_Num = -1;
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM Cls_Metodos_Pago WHERE Descripcion = @Descripcion)
        BEGIN
            SET @O_Msg = 'Ya existe un método de pago con esa descripción.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;
            INSERT INTO Cls_Metodos_Pago (
                Descripcion, 
                Id_Estado, 
                Activo, 
                Fecha_Creacion, 
                Fecha_Modificacion,
                Id_Creador, 
                Id_Modificador
            )
            VALUES (
                @Descripcion, 
                @Id_Estado, 
                1, 
                GETDATE(), 
                GETDATE(),
                @Id_Creador, 
                @Id_Modificador
            );
            SET @O_Num = SCOPE_IDENTITY();
            SET @O_Msg = 'Método de pago registrado.';
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
        IF @Id_Metodo_Pago IS NULL
        BEGIN
            SET @O_Msg = 'Id requerido.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;
            UPDATE Cls_Metodos_Pago
            SET Descripcion = COALESCE(@Descripcion, Descripcion),
                Id_Estado = COALESCE(@Id_Estado, Id_Estado),
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = COALESCE(@Id_Modificador, Id_Modificador)
            WHERE Id_Metodo_Pago = @Id_Metodo_Pago;

            SET @O_Num = @Id_Metodo_Pago;
            SET @O_Msg = 'Método de pago actualizado.';
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
        BEGIN TRY
            UPDATE Cls_Metodos_Pago
            SET Id_Estado = 2,
                Activo = 0,
                Id_Modificador = @Id_Modificador,
                Fecha_Modificacion = GETDATE()
            WHERE Id_Metodo_Pago = @Id_Metodo_Pago;
            
            SET @O_Msg = 'Método inactivado.';
            SET @O_Num = @Id_Metodo_Pago;
        END TRY
        BEGIN CATCH
            SET @O_Msg = ERROR_MESSAGE();
            SET @O_Num = -1;
        END CATCH
    END

    ELSE IF @Mode = 'LST'
    BEGIN
        SELECT 
            m.Id_Metodo_Pago, 
            m.Descripcion, 
            m.Id_Estado, 
            e.Estado,
            m.Activo,
            m.Fecha_Creacion, 
            m.Fecha_Modificacion,
            m.Id_Creador,
            m.Id_Modificador
        FROM Cls_Metodos_Pago m
        LEFT JOIN Cls_Estados e ON m.Id_Estado = e.Id_Estado;
        
        SET @O_Msg = 'Listado generado.';
        SET @O_Num = 0;
    END

ELSE IF @Mode = 'FIL'
    BEGIN
        -- 1. Intentamos convertir el filtro a número para buscar por ID
        DECLARE @FiltroID INT = TRY_CAST(@Filtro AS INT);
        
        IF ISNULL(@Filtro, '') = '' SET @Filtro = '';
        
        SELECT 
            m.Id_Metodo_Pago, 
            m.Descripcion, 
            m.Id_Estado, 
            e.Estado,
            m.Activo,
            m.Fecha_Creacion,
            m.Fecha_Modificacion,
            m.Id_Creador,
            m.Id_Modificador
        FROM Cls_Metodos_Pago m
        LEFT JOIN Cls_Estados e ON m.Id_Estado = e.Id_Estado
        WHERE 
            -- Búsqueda por texto
            m.Descripcion LIKE '%' + @Filtro + '%'
            -- Búsqueda por ID (solo si el filtro es numérico)
            OR (@FiltroID IS NOT NULL AND m.Id_Metodo_Pago = @FiltroID)
            -- Búsqueda por el parámetro directo de ID
            OR (m.Id_Metodo_Pago = @Id_Metodo_Pago);
        
        SET @O_Msg = 'Filtro aplicado correctamente.';
        SET @O_Num = 0;
    END

    ELSE
    BEGIN
        SET @O_Msg = 'Modo no reconocido.';
        SET @O_Num = -1;
    END
END
GO