USE NicaTek;
GO

CREATE OR ALTER PROC sp_Tbl_Configuracion_Empresa
    @Mode VARCHAR(3) = NULL,
    @O_Msg VARCHAR(255) = NULL OUTPUT,
    @O_Num INT = NULL OUTPUT,

    @Id_Configuracion INT = NULL,
    @Nombre_Empresa VARCHAR(100) = NULL,
    @RUC_No VARCHAR(50) = NULL,        -- Corregido
    @Direccion VARCHAR(255) = NULL,
    @Telefono VARCHAR(20) = NULL,
    @Correo_Empresa VARCHAR(100) = NULL, -- Corregido
    @Ruta_Logo VARCHAR(255) = NULL,
    @Moneda_Simbolo VARCHAR(5) = NULL,
    @Id_Modificador INT = NULL -- Usuario que hace el cambio
AS
BEGIN
    SET NOCOUNT ON;

    -- INSERTAR (Configuración Inicial)
    IF @Mode = 'INS'
    BEGIN
        -- Validar que no exista ya una configuración (Solo 1 empresa permitida)
        IF EXISTS (SELECT 1 FROM Tbl_Configuracion_Empresa)
        BEGIN
            SET @O_Msg = 'Ya existe una configuración. Use actualizar (UPD).';
            SET @O_Num = -1;
            RETURN;
        END

        IF @Nombre_Empresa IS NULL OR @RUC_No IS NULL
        BEGIN
            SET @O_Msg = 'Nombre y RUC son obligatorios.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            INSERT INTO Tbl_Configuracion_Empresa (
                Nombre_Empresa, RUC_No, Direccion, Telefono, 
                Correo_Empresa, Ruta_Logo, Moneda_Simbolo, 
                Fecha_Modificacion, Id_Modificador
            )
            VALUES (
                @Nombre_Empresa, @RUC_No, ISNULL(@Direccion, 'N/A'), @Telefono, 
                @Correo_Empresa, @Ruta_Logo, ISNULL(@Moneda_Simbolo, 'C$'), 
                GETDATE(), @Id_Modificador
            );
            
            SET @O_Num = SCOPE_IDENTITY();
            SET @O_Msg = 'Empresa configurada exitosamente.';
        END TRY
        BEGIN CATCH
            SET @O_Msg = ERROR_MESSAGE();
            SET @O_Num = -1;
        END CATCH
    END

    -- ACTUALIZAR (Modificar datos de la empresa)
    ELSE IF @Mode = 'UPD'
    BEGIN
        -- Si no envían ID, intentamos actualizar el único registro que haya (Top 1)
        DECLARE @TargetID INT = @Id_Configuracion;
        IF @TargetID IS NULL
            SELECT TOP 1 @TargetID = Id_Configuracion FROM Tbl_Configuracion_Empresa;

        IF @TargetID IS NULL
        BEGIN
            SET @O_Msg = 'No hay configuración para actualizar.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            UPDATE Tbl_Configuracion_Empresa
            SET Nombre_Empresa = COALESCE(@Nombre_Empresa, Nombre_Empresa),
                RUC_No = COALESCE(@RUC_No, RUC_No),
                Direccion = COALESCE(@Direccion, Direccion),
                Telefono = COALESCE(@Telefono, Telefono),
                Correo_Empresa = COALESCE(@Correo_Empresa, Correo_Empresa),
                Ruta_Logo = COALESCE(@Ruta_Logo, Ruta_Logo),
                Moneda_Simbolo = COALESCE(@Moneda_Simbolo, Moneda_Simbolo),
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = COALESCE(@Id_Modificador, Id_Modificador)
            WHERE Id_Configuracion = @TargetID;

            SET @O_Msg = 'Datos de la empresa actualizados.';
            SET @O_Num = @TargetID;
        END TRY
        BEGIN CATCH
            SET @O_Msg = ERROR_MESSAGE();
            SET @O_Num = -1;
        END CATCH
    END

    -- OBTENER DATOS (GET) - Para cargar en el Login o Reportes
    ELSE IF @Mode = 'GET' OR @Mode = 'LST'
    BEGIN
        SELECT TOP 1
            Id_Configuracion,
            Nombre_Empresa,
            RUC_No,
            Direccion,
            Telefono,
            Correo_Empresa,
            Ruta_Logo,
            Moneda_Simbolo,
            Fecha_Modificacion
        FROM Tbl_Configuracion_Empresa;
        
        SET @O_Msg = 'Datos recuperados.';
        SET @O_Num = 0;
    END
END
GO