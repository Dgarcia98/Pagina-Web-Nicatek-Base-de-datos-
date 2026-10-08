USE NicaTek;
GO

CREATE OR ALTER PROC sp_Cls_Tipo_Movimiento
    @Mode VARCHAR(3) = NULL,
    @O_Msg VARCHAR(255) = NULL OUTPUT,
    @O_Num INT = NULL OUTPUT,
    @Id_Tipo_Movimiento INT = NULL,
    @Descripcion VARCHAR(50) = NULL,
    @Operacion VARCHAR(10) = NULL,
    @Id_Estado INT = NULL,
    @Id_Creador INT = NULL,
    @Id_Modificador INT = NULL,
    @Filtro VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Mode = 'INS'
    BEGIN
        IF @Descripcion IS NULL OR @Operacion IS NULL OR @Id_Estado IS NULL
        BEGIN
            SET @O_Msg = 'Faltan campos obligatorios.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;
            INSERT INTO Cls_Tipo_Movimiento (
                Descripcion, Operacion, Id_Estado, Activo,
                Fecha_Creacion, Fecha_Modificacion,
                Id_Creador, Id_Modificador
            )
            VALUES (
                @Descripcion, @Operacion, @Id_Estado, 1,
                GETDATE(), GETDATE(),
                @Id_Creador, @Id_Modificador
            );
            SET @O_Num = SCOPE_IDENTITY();
            SET @O_Msg = 'Tipo de movimiento registrado.';
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
        IF @Id_Tipo_Movimiento IS NULL
        BEGIN
            SET @O_Msg = 'Id requerido.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;
            UPDATE Cls_Tipo_Movimiento
            SET Descripcion = COALESCE(@Descripcion, Descripcion),
                Operacion = COALESCE(@Operacion, Operacion),
                Id_Estado = COALESCE(@Id_Estado, Id_Estado),
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = COALESCE(@Id_Modificador, Id_Modificador)
            WHERE Id_Tipo_Movimiento = @Id_Tipo_Movimiento;

            SET @O_Num = @Id_Tipo_Movimiento;
            SET @O_Msg = 'Registro actualizado.';
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
            UPDATE Cls_Tipo_Movimiento
            SET Id_Estado = 2,
                Activo = 0,
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = @Id_Modificador
            WHERE Id_Tipo_Movimiento = @Id_Tipo_Movimiento;

            SET @O_Msg = 'Registro inactivado.';
            SET @O_Num = @Id_Tipo_Movimiento;
        END TRY
        BEGIN CATCH
            SET @O_Msg = ERROR_MESSAGE();
            SET @O_Num = -1;
        END CATCH
    END

    ELSE IF @Mode = 'LST'
    BEGIN
        SELECT 
            tm.Id_Tipo_Movimiento, 
            tm.Descripcion, 
            tm.Operacion,
            tm.Id_Estado, 
            e.Estado AS Nombre_Estado,
            tm.Activo,
            tm.Id_Creador,
            tm.Id_Modificador,
            tm.Fecha_Creacion,
            tm.Fecha_Modificacion
        FROM Cls_Tipo_Movimiento tm
        LEFT JOIN Cls_Estados e ON tm.Id_Estado = e.Id_Estado;

        SET @O_Msg = 'Listado generado.';
        SET @O_Num = 0;
    END

    ELSE IF @Mode = 'FIL'
    BEGIN
        SELECT 
            tm.Id_Tipo_Movimiento, 
            tm.Descripcion,
            tm.Operacion,
            tm.Id_Estado, 
            e.Estado AS Nombre_Estado,
            tm.Activo,
            tm.Id_Creador,
            tm.Id_Modificador,
            tm.Fecha_Creacion,
            tm.Fecha_Modificacion
        FROM Cls_Tipo_Movimiento tm
        LEFT JOIN Cls_Estados e ON tm.Id_Estado = e.Id_Estado
        WHERE tm.Descripcion LIKE '%' + ISNULL(@Filtro, '') + '%';

        SET @O_Msg = 'Filtro aplicado.';
        SET @O_Num = 0;
    END
END
GO