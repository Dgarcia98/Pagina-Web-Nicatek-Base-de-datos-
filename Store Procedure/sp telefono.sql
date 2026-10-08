USE NICATEK;
GO

CREATE OR ALTER PROC sp_Tbl_Telefonos
    @Mode VARCHAR(3) = NULL,
    @O_Msg VARCHAR(255) = NULL OUTPUT,
    @O_Num INT = NULL OUTPUT,
    @Id_Telefono INT = NULL,
    @Id_Persona INT = NULL,
    @Numero_Telefono VARCHAR(20) = NULL,
    @Id_Tipo_Telefono INT = NULL,
    @Id_Creador INT = NULL,
    @Id_Modificador INT = NULL,
    @Activo BIT = NULL,
    @Filtro VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Mode = 'INS'
    BEGIN
        IF @Id_Persona IS NULL OR @Numero_Telefono IS NULL OR @Id_Tipo_Telefono IS NULL OR
           @Id_Creador IS NULL OR @Id_Modificador IS NULL OR @Activo IS NULL
        BEGIN
            SET @O_Msg = 'Faltan campos obligatorios.';
            SET @O_Num = -1;
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Tbl_Datos_Personales WHERE Id_Persona = @Id_Persona)
        BEGIN
            SET @O_Msg = 'La persona especificada no existe.';
            SET @O_Num = -1;
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM Cls_Catalogos WHERE Id_Catalogo = @Id_Tipo_Telefono)
        BEGIN
            SET @O_Msg = 'El tipo de teléfono especificado no existe.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            INSERT INTO Tbl_Telefonos (
                Id_Persona, Numero_Telefono, Id_Tipo_Telefono,
                Fecha_Creacion, Fecha_Modificacion,
                Id_Creador, Id_Modificador, Activo
            )
            VALUES (
                @Id_Persona, @Numero_Telefono, @Id_Tipo_Telefono,
                GETDATE(), GETDATE(), @Id_Creador, @Id_Modificador, @Activo
            );

            SET @O_Num = SCOPE_IDENTITY();
            SET @O_Msg = 'Teléfono registrado correctamente.';
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
        IF @Id_Telefono IS NULL
        BEGIN
            SET @O_Msg = 'Id_Telefono requerido para actualizar.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            UPDATE Tbl_Telefonos
            SET Numero_Telefono = COALESCE(@Numero_Telefono, Numero_Telefono),
                Id_Tipo_Telefono = COALESCE(@Id_Tipo_Telefono, Id_Tipo_Telefono),
                Id_Persona = COALESCE(@Id_Persona, Id_Persona),
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = COALESCE(@Id_Modificador, Id_Modificador),
                Activo = COALESCE(@Activo, Activo)
            WHERE Id_Telefono = @Id_Telefono;

            IF @@ROWCOUNT = 0
            BEGIN
                ROLLBACK;
                SET @O_Msg = 'No se actualizó ninguna fila. Verificá el Id_Telefono.';
                SET @O_Num = -1;
                RETURN;
            END

            SET @O_Num = @Id_Telefono;
            SET @O_Msg = 'Teléfono actualizado correctamente.';
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
        IF EXISTS (SELECT 1 FROM Tbl_Telefonos)
        BEGIN
            SET @O_Msg = 'Listado de teléfonos.';
            SET @O_Num = 0;

            SELECT 
                t.Id_Telefono,
                t.Numero_Telefono,
                t.Id_Tipo_Telefono,
                t.Id_Persona,
                c.Catalogo AS Tipo_Telefono,
                t.Fecha_Creacion,
                t.Fecha_Modificacion,
                t.Id_Creador,      
                t.Id_Modificador,  
                t.Activo,
                CASE WHEN t.Activo = 1 THEN 'Sí' ELSE 'No' END AS EstadoActivo
            FROM Tbl_Telefonos t
            JOIN Cls_Catalogos c ON t.Id_Tipo_Telefono = c.Id_Catalogo;
        END
        ELSE
        BEGIN
            SET @O_Msg = 'No hay teléfonos registrados.';
            SET @O_Num = 0;
        END
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
            DECLARE @FiltroInt INT;
            SET @FiltroInt = TRY_CAST(@Filtro AS INT); 

            IF EXISTS (
                SELECT 1
                FROM Tbl_Telefonos t
                JOIN Cls_Catalogos c ON t.Id_Tipo_Telefono = c.Id_Catalogo
                WHERE t.Numero_Telefono LIKE '%' + @Filtro + '%'
                    OR CAST(t.Id_Telefono AS VARCHAR) = @Filtro
                    OR c.Catalogo LIKE '%' + @Filtro + '%'
                    OR (@FiltroInt IS NOT NULL AND t.Id_Persona = @FiltroInt) 
            )
            BEGIN
                SET @O_Msg = 'Consulta con filtro realizada.';
                SET @O_Num = 0;

                SELECT 
                    t.Id_Telefono,
                    t.Numero_Telefono,
                    t.Id_Tipo_Telefono,
                    t.Id_Persona,
                    c.Catalogo AS Tipo_Telefono,
                    t.Fecha_Creacion,
                    t.Fecha_Modificacion,
                    t.Id_Creador,    
                    t.Id_Modificador,   
                    t.Activo,
                    CASE WHEN t.Activo = 1 THEN 'Sí' ELSE 'No' END AS EstadoActivo
                FROM Tbl_Telefonos t
                JOIN Cls_Catalogos c ON t.Id_Tipo_Telefono = c.Id_Catalogo
                WHERE t.Numero_Telefono LIKE '%' + @Filtro + '%'
                    OR CAST(t.Id_Telefono AS VARCHAR) = @Filtro
                    OR c.Catalogo LIKE '%' + @Filtro + '%'
                    OR (@FiltroInt IS NOT NULL AND t.Id_Persona = @FiltroInt); 
            END
            ELSE
            BEGIN
                SET @O_Msg = 'No se encontraron teléfonos con ese filtro.';
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