/* =====================================================================
   001 - INDICES
   ---------------------------------------------------------------------
   La base no tenia NI UN indice no-clustered. Cada JOIN por clave foranea
   era un table scan. Este script es idempotente: se puede correr varias
   veces sin error.

   Tiempo estimado: segundos con los datos actuales. Correr en horario
   de baja carga si la base ya crecio (los CREATE INDEX bloquean la tabla
   en la edicion Standard de Azure SQL).
   ===================================================================== */
USE NicaTek;
GO

SET NOCOUNT ON;

/* ---------- Ventas ------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Ventas_Fecha')
    CREATE NONCLUSTERED INDEX IX_Ventas_Fecha
        ON Tbl_Ventas (Fecha)
        INCLUDE (Total, Id_Estado, Id_Cliente);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Ventas_Cliente')
    CREATE NONCLUSTERED INDEX IX_Ventas_Cliente
        ON Tbl_Ventas (Id_Cliente);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Ventas_Estado')
    CREATE NONCLUSTERED INDEX IX_Ventas_Estado
        ON Tbl_Ventas (Id_Estado)
        INCLUDE (Fecha, Total);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Ventas_Empleado')
    CREATE NONCLUSTERED INDEX IX_Ventas_Empleado
        ON Tbl_Ventas (Id_Empleado);
GO

/* ---------- Detalle de venta ---------------------------------------- */
-- El mas importante de todos: el resumen de una venta lo usa en cada carga.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Detalle_Venta_Venta')
    CREATE NONCLUSTERED INDEX IX_Detalle_Venta_Venta
        ON Tbl_Detalle_Venta (Id_Venta)
        INCLUDE (Id_Producto, Id_Bodega, Cantidad, Subtotal,
                 Precio_Unitario_Al_Momento_Venta, Id_Estado);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Detalle_Venta_Producto')
    CREATE NONCLUSTERED INDEX IX_Detalle_Venta_Producto
        ON Tbl_Detalle_Venta (Id_Producto)
        INCLUDE (Cantidad, Subtotal);
GO

/* ---------- Compras ------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Compra_Fecha')
    CREATE NONCLUSTERED INDEX IX_Compra_Fecha
        ON Tbl_Compra (Fecha_Compra)
        INCLUDE (Total_Compra, Id_Estado, Id_Proveedor);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Compra_Proveedor')
    CREATE NONCLUSTERED INDEX IX_Compra_Proveedor
        ON Tbl_Compra (Id_Proveedor);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Detalle_Compra_Compra')
    CREATE NONCLUSTERED INDEX IX_Detalle_Compra_Compra
        ON Tbl_Detalle_Compra (Id_Compra)
        INCLUDE (Id_Producto, Cantidad, Subtotal_Compra, Precio_Unitario_Compra);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Detalle_Compra_Producto')
    CREATE NONCLUSTERED INDEX IX_Detalle_Compra_Producto
        ON Tbl_Detalle_Compra (Id_Producto);
GO

/* ---------- Inventario ---------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Bodega_Producto_Producto')
    CREATE NONCLUSTERED INDEX IX_Bodega_Producto_Producto
        ON Tbl_Bodega_Producto (Id_Producto)
        INCLUDE (Id_Bodega, Cantidad);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Mov_Inventario_Producto_Fecha')
    CREATE NONCLUSTERED INDEX IX_Mov_Inventario_Producto_Fecha
        ON Tbl_Movimientos_Inventario (Id_Producto, Fecha_Movimiento DESC)
        INCLUDE (Cantidad, Stock_Anterior, Stock_Actual, Id_Tipo_Movimiento);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Mov_Inventario_BodegaProducto')
    CREATE NONCLUSTERED INDEX IX_Mov_Inventario_BodegaProducto
        ON Tbl_Movimientos_Inventario (Id_Bodega_Producto)
        INCLUDE (Cantidad, Id_Tipo_Movimiento, Fecha_Movimiento);
GO

/* ---------- Producto y catalogos ------------------------------------ */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Producto_Categoria')
    CREATE NONCLUSTERED INDEX IX_Producto_Categoria
        ON Tbl_Producto (Id_Categoria)
        INCLUDE (Nombre, Precio, Id_Estado);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Producto_MarcaModelo')
    CREATE NONCLUSTERED INDEX IX_Producto_MarcaModelo
        ON Tbl_Producto (Id_Marca_Modelo);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Producto_Estado')
    CREATE NONCLUSTERED INDEX IX_Producto_Estado
        ON Tbl_Producto (Id_Estado)
        INCLUDE (Codigo, Nombre, Precio);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Marca_Modelo_Marca')
    CREATE NONCLUSTERED INDEX IX_Marca_Modelo_Marca
        ON Tbl_Marca_Modelo (Id_Marca, Id_Modelo);
GO

/* ---------- Personas y accesos -------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Usuarios_Persona')
    CREATE NONCLUSTERED INDEX IX_Usuarios_Persona
        ON Tbl_Usuarios (Id_Persona);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Usuarios_Rol')
    CREATE NONCLUSTERED INDEX IX_Usuarios_Rol
        ON Tbl_Usuarios (Id_Rol);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Cliente_Persona')
    CREATE NONCLUSTERED INDEX IX_Cliente_Persona
        ON Tbl_Cliente (Id_Persona);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Correos_Persona')
    CREATE NONCLUSTERED INDEX IX_Correos_Persona
        ON Tbl_Correos (Id_Persona);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Telefonos_Persona')
    CREATE NONCLUSTERED INDEX IX_Telefonos_Persona
        ON Tbl_Telefonos (Id_Persona);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Direcciones_Persona')
    CREATE NONCLUSTERED INDEX IX_Direcciones_Persona
        ON Tbl_Direcciones (Id_Persona);
GO
-- Login: se consulta en cada autenticacion.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Usuarios_Nombre_Estado')
    CREATE NONCLUSTERED INDEX IX_Usuarios_Nombre_Estado
        ON Tbl_Usuarios (Nombre_Usuario, Id_Estado)
        INCLUDE (Contrasena, Id_Rol, Id_Persona);
GO
-- Permisos: se consulta en cada request una vez que la API valide permisos.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Roles_Permisos_Rol')
    CREATE NONCLUSTERED INDEX IX_Roles_Permisos_Rol
        ON Tbl_Roles_Permisos (Id_Rol, Activo)
        INCLUDE (Id_Permiso);
GO

/* ---------- Catalogos genericos ------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Catalogos_Tipo')
    CREATE NONCLUSTERED INDEX IX_Catalogos_Tipo
        ON Cls_Catalogos (Id_Tipo_Catalogo)
        INCLUDE (Catalogo, Activo);
GO

PRINT 'OK - Indices creados. Verificacion:';
SELECT  OBJECT_NAME(i.object_id) AS Tabla, i.name AS Indice, i.type_desc
FROM sys.indexes i
WHERE i.name LIKE 'IX_%'
ORDER BY Tabla, Indice;
GO
