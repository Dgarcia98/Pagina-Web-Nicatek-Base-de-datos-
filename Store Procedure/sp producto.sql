USE NicaTek;
GO

CREATE OR ALTER PROC sp_Tbl_Producto
    @Mode VARCHAR(3) = NULL,
    @O_Msg VARCHAR(255) = NULL OUTPUT,
    @O_Num INT = NULL OUTPUT,
    @Id_Producto INT = NULL,
    @Codigo VARCHAR(50) = NULL,
    @Nombre VARCHAR(150) = NULL,
    @Descripcion VARCHAR(250) = NULL,
    @Precio DECIMAL(12,2) = NULL,
    @Precio_Compra DECIMAL(12,2) = NULL,
    @Id_Marca_Modelo INT = NULL,
    @Id_Proveedor INT = NULL,
    @Id_Categoria INT = NULL,
    @Id_Estado INT = NULL,
    @Id_Creador INT = NULL,
    @Id_Modificador INT = NULL,
    @Filtro VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Mode = 'INS'
    BEGIN
        IF @Codigo IS NULL OR @Nombre IS NULL OR @Precio IS NULL OR
           @Id_Marca_Modelo IS NULL OR @Id_Proveedor IS NULL OR
           @Id_Categoria IS NULL OR @Id_Estado IS NULL OR
           @Id_Creador IS NULL OR @Id_Modificador IS NULL
        BEGIN
            SET @O_Msg = 'Faltan campos obligatorios.';
            SET @O_Num = -1;
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM Tbl_Producto WHERE Codigo = @Codigo AND Id_Estado = 1)
        BEGIN
            SET @O_Msg = 'Ya existe un producto activo con ese código.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;
            INSERT INTO Tbl_Producto (
                Codigo, Nombre, Descripcion, Precio, Precio_Compra,
                Id_Marca_Modelo, Id_Proveedor, Id_Categoria, Id_Estado,
                Fecha_Creacion, Fecha_Modificacion,
                Id_Creador, Id_Modificador
            )
            VALUES (
                @Codigo, @Nombre, @Descripcion, @Precio, @Precio_Compra,
                @Id_Marca_Modelo, @Id_Proveedor, @Id_Categoria, @Id_Estado,
                GETDATE(), GETDATE(),
                @Id_Creador, @Id_Modificador
            );
            SET @O_Num = SCOPE_IDENTITY();
            SET @O_Msg = 'Producto registrado correctamente.';
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
        IF @Id_Producto IS NULL
        BEGIN
            SET @O_Msg = 'Id_Producto requerido para actualizar.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;
            UPDATE Tbl_Producto
            SET Codigo = COALESCE(@Codigo, Codigo),
                Nombre = COALESCE(@Nombre, Nombre),
                Descripcion = COALESCE(@Descripcion, Descripcion),
                Precio = COALESCE(@Precio, Precio),
                Precio_Compra = COALESCE(@Precio_Compra, Precio_Compra),
                Id_Marca_Modelo = COALESCE(@Id_Marca_Modelo, Id_Marca_Modelo),
                Id_Proveedor = COALESCE(@Id_Proveedor, Id_Proveedor),
                Id_Categoria = COALESCE(@Id_Categoria, Id_Categoria),
                Id_Estado = COALESCE(@Id_Estado, Id_Estado),
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = COALESCE(@Id_Modificador, Id_Modificador)
            WHERE Id_Producto = @Id_Producto;
            SET @O_Num = @Id_Producto;
            SET @O_Msg = 'Producto actualizado correctamente.';
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
        IF @Id_Producto IS NULL OR @Id_Modificador IS NULL
        BEGIN
            SET @O_Msg = 'Id_Producto e Id_Modificador requeridos para eliminar.';
            SET @O_Num = -1;
            RETURN;
        END

        BEGIN TRY
            BEGIN TRAN;
            UPDATE Tbl_Producto
            SET Id_Estado = 2, 
                Fecha_Modificacion = GETDATE(),
                Id_Modificador = @Id_Modificador
            WHERE Id_Producto = @Id_Producto;
            SET @O_Num = @Id_Producto;
            SET @O_Msg = 'Producto eliminado (inactivado) correctamente.';
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
            p.Id_Producto,
            p.Codigo,
            p.Nombre,
            p.Descripcion,
            p.Precio,
            p.Precio_Compra,
            b.Id_Bodega, 
            ISNULL(b.Cantidad, 0) AS Stock,
            p.Id_Marca_Modelo,
            m.Nombre_Marca,
            mo.Nombre_Modelo,
            p.Id_Proveedor,
            dp.Primer_Nombre + ' ' + dp.Primer_Apellido AS Proveedor,
            p.Id_Categoria,
            c.Nombre AS Categoria,
            p.Id_Estado,
            e.Estado,
            p.Fecha_Creacion,
            p.Fecha_Modificacion,
            p.Id_Creador,
            p.Id_Modificador
        FROM Tbl_Producto p
        JOIN Tbl_Marca_Modelo mm ON p.Id_Marca_Modelo = mm.Id_Marca_Modelo
        JOIN Cls_Marca m ON mm.Id_Marca = m.Id_Marca
        JOIN Cls_Modelo mo ON mm.Id_Modelo = mo.Id_Modelo
        JOIN Tbl_Proveedor pr ON p.Id_Proveedor = pr.Id_Proveedor
        JOIN Tbl_Datos_Personales dp ON pr.Id_Persona = dp.Id_Persona
        JOIN Tbl_Categoria c ON p.Id_Categoria = c.Id_Categoria
        JOIN Cls_Estados e ON p.Id_Estado = e.Id_Estado
        LEFT JOIN Tbl_Bodega b ON p.Id_Producto = b.Id_Producto 
       -- WHERE p.Id_Estado = 1;

        SET @O_Msg = 'Listado de productos.';
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
            p.Id_Producto,
            p.Codigo,
            p.Nombre,
            p.Descripcion,
            p.Precio,
            p.Precio_Compra,
            b.Id_Bodega,
            ISNULL(b.Cantidad, 0) AS Stock,
            p.Id_Marca_Modelo,
            m.Nombre_Marca,
            mo.Nombre_Modelo,
            p.Id_Proveedor,
            dp.Primer_Nombre + ' ' + dp.Primer_Apellido AS Proveedor,
            p.Id_Categoria,
            c.Nombre AS Categoria,
            p.Id_Estado,
            e.Estado,
            p.Fecha_Creacion,
            p.Fecha_Modificacion,
            p.Id_Creador,
            p.Id_Modificador
        FROM Tbl_Producto p
        JOIN Tbl_Marca_Modelo mm ON p.Id_Marca_Modelo = mm.Id_Marca_Modelo
        JOIN Cls_Marca m ON mm.Id_Marca = m.Id_Marca
        JOIN Cls_Modelo mo ON mm.Id_Modelo = mo.Id_Modelo
        JOIN Tbl_Proveedor pr ON p.Id_Proveedor = pr.Id_Proveedor
        JOIN Tbl_Datos_Personales dp ON pr.Id_Persona = dp.Id_Persona
        JOIN Tbl_Categoria c ON p.Id_Categoria = c.Id_Categoria
        JOIN Cls_Estados e ON p.Id_Estado = e.Id_Estado
        LEFT JOIN Tbl_Bodega b ON p.Id_Producto = b.Id_Producto
        WHERE (p.Codigo LIKE '%' + @Filtro + '%'
            OR p.Nombre LIKE '%' + @Filtro + '%'
            OR m.Nombre_Marca LIKE '%' + @Filtro + '%'
            OR mo.Nombre_Modelo LIKE '%' + @Filtro + '%'
            OR dp.Primer_Nombre LIKE '%' + @Filtro + '%'
            OR dp.Primer_Apellido LIKE '%' + @Filtro + '%'
            OR c.Nombre LIKE '%' + @Filtro + '%'
            OR CAST(p.Id_Producto AS VARCHAR) = @Filtro)
           -- AND p.Id_Estado = 1;

        SET @O_Msg = 'Consulta filtrada correctamente.';
        SET @O_Num = 0;
    END

    ELSE
    BEGIN
        SET @O_Msg = 'Modo no reconocido.';
        SET @O_Num = -1;
    END
END
GO