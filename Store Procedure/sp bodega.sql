CREATE OR ALTER PROC sp_Tbl_Bodega
    @Mode VARCHAR(3) = NULL,
    @O_Msg VARCHAR(255) = NULL OUTPUT,
    @O_Num INT = NULL OUTPUT,

    @Id_Bodega INT = NULL,
    @Id_Producto INT = NULL,
    @Cantidad INT = NULL,
    @Id_Estado INT = NULL,
    @Id_Creador INT = NULL,
    @Id_Modificador INT = NULL,
    @Filtro VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Mode = 'INS'
    BEGIN
        IF @Id_Producto IS NULL OR @Id_Estado IS NULL OR
           @Id_Creador IS NULL OR @Id_Modificador IS NULL
        BEGIN
            SET @O_Msg = 'Faltan campos obligatorios.';
            SET @O_Num = -1;
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM Tbl_Bodega WHERE Id_Producto = @Id_Producto AND Id_Estado = 1)
        BEGIN
            SET @O_Msg = 'Este producto ya existe en la bodega activa.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            INSERT INTO Tbl_Bodega (
                Id_Producto, Cantidad, Id_Estado,
                Fecha_Creacion, Fecha_Modificacion,
                Id_Creador, Id_Modificador
            )
            VALUES (
                @Id_Producto, COALESCE(@Cantidad, 0), @Id_Estado,
                GETDATE(), GETDATE(), @Id_Creador, @Id_Modificador
            );

            SET @O_Num = SCOPE_IDENTITY();
            SET @O_Msg = 'Inventario registrado en bodega.';
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
        IF @Id_Bodega IS NULL
        BEGIN
            SET @O_Msg = 'Id_Bodega requerido para actualizar.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            UPDATE Tbl_Bodega
            SET Cantidad = COALESCE(@Cantidad, Cantidad),
                Id_Estado = COALESCE(@Id_Estado, Id_Estado),
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = COALESCE(@Id_Modificador, Id_Modificador)
            WHERE Id_Bodega = @Id_Bodega;

            SET @O_Num = @Id_Bodega;
            SET @O_Msg = 'Registro actualizado correctamente.';
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
        IF @Id_Bodega IS NULL OR @Id_Modificador IS NULL
        BEGIN
            SET @O_Msg = 'Id_Bodega e Id_Modificador requeridos para eliminar.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;

            UPDATE Tbl_Bodega
            SET Id_Estado = 2,
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = @Id_Modificador
            WHERE Id_Bodega = @Id_Bodega;

            SET @O_Num = @Id_Bodega;
            SET @O_Msg = 'Registro eliminado (inactivado) correctamente.';
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
            b.Id_Bodega,
            b.Id_Producto,
            p.Codigo,
            p.Nombre AS Nombre_Producto,
            p.Precio AS Precio_Producto,
            mm.Id_Marca,
            m.Nombre_Marca,
            mm.Id_Modelo,
            mo.Nombre_Modelo,
            c.Nombre AS Nombre_Categoria,  -- NUEVO
            b.Cantidad,
            b.Id_Estado,
            e.Estado,
            b.Fecha_Creacion,
            b.Fecha_Modificacion,
            b.Id_Creador,
            b.Id_Modificador
        FROM Tbl_Bodega b
        JOIN Tbl_Producto p      ON b.Id_Producto = p.Id_Producto
        JOIN Tbl_Marca_Modelo mm ON p.Id_Marca_Modelo = mm.Id_Marca_Modelo
        JOIN Cls_Marca m         ON mm.Id_Marca = m.Id_Marca
        JOIN Cls_Modelo mo       ON mm.Id_Modelo = mo.Id_Modelo
        JOIN Tbl_Categoria c     ON p.Id_Categoria = c.Id_Categoria  -- NUEVO
        JOIN Cls_Estados e       ON b.Id_Estado = e.Id_Estado
        WHERE b.Id_Estado = 1;

        SET @O_Msg = 'Listado de bodega.';
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
            b.Id_Bodega,
            b.Id_Producto,
            p.Codigo,
            p.Nombre AS Nombre_Producto,
            p.Precio AS Precio_Producto,
            mm.Id_Marca,
            m.Nombre_Marca,
            mm.Id_Modelo,
            mo.Nombre_Modelo,
            c.Nombre AS Nombre_Categoria,  -- NUEVO
            b.Cantidad,
            b.Id_Estado,
            e.Estado,
            b.Fecha_Creacion,
            b.Fecha_Modificacion,
            b.Id_Creador,
            b.Id_Modificador
        FROM Tbl_Bodega b
        JOIN Tbl_Producto p      ON b.Id_Producto = p.Id_Producto
        JOIN Tbl_Marca_Modelo mm ON p.Id_Marca_Modelo = mm.Id_Marca_Modelo
        JOIN Cls_Marca m         ON mm.Id_Marca = m.Id_Marca
        JOIN Cls_Modelo mo       ON mm.Id_Modelo = mo.Id_Modelo
        JOIN Tbl_Categoria c     ON p.Id_Categoria = c.Id_Categoria  --  NUEVO
        JOIN Cls_Estados e       ON b.Id_Estado = e.Id_Estado
        WHERE (p.Codigo LIKE '%' + @Filtro + '%'
            OR p.Nombre LIKE '%' + @Filtro + '%'
            OR m.Nombre_Marca LIKE '%' + @Filtro + '%'
            OR mo.Nombre_Modelo LIKE '%' + @Filtro + '%'
            OR c.Nombre LIKE '%' + @Filtro + '%'   -- NUEVO: filtrar por categoría
            OR CAST(b.Id_Bodega AS VARCHAR) = @Filtro)
            AND b.Id_Estado = 1;

        SET @O_Msg = 'Consulta de bodega filtrada.';
        SET @O_Num = 0;
    END

    ELSE
    BEGIN
        SET @O_Msg = 'Modo no reconocido.';
        SET @O_Num = -1;
    END
END
GO