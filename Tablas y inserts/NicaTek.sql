Create Database Nicatek
go

USE NicaTek;
GO

CREATE TABLE Cls_Estados ( 
    Id_Estado INT PRIMARY KEY IDENTITY(1,1),
    Estado VARCHAR(80) NOT NULL UNIQUE,
    Fecha_Creacion DATETIME NOT NULL DEFAULT GETDATE(),
    Fecha_Modificacion DATETIME NOT NULL DEFAULT GETDATE(),
    Id_Creador INT NULL, 
    Id_Modificador INT NULL,
    Activo BIT DEFAULT 1
);

CREATE TABLE Cls_Tipo_Catalogos ( 
    Id_Tipo_Catalogo INT PRIMARY KEY IDENTITY(1,1),
    Tipo_Catalogo VARCHAR(80) NOT NULL UNIQUE,
    Fecha_Creacion DATETIME NOT NULL DEFAULT GETDATE(),
    Fecha_Modificacion DATETIME NOT NULL DEFAULT GETDATE(),
    Id_Creador INT NULL,
    Id_Modificador INT NULL,
    Activo BIT DEFAULT 1
);

CREATE TABLE Cls_Catalogos ( 
    Id_Catalogo INT PRIMARY KEY IDENTITY(1,1),
    Id_Tipo_Catalogo INT NOT NULL REFERENCES Cls_Tipo_Catalogos(Id_Tipo_Catalogo),
    Catalogo VARCHAR(80) NOT NULL,
    Fecha_Creacion DATETIME NOT NULL DEFAULT GETDATE(),
    Fecha_Modificacion DATETIME NOT NULL DEFAULT GETDATE(),
    Activo BIT DEFAULT 1,
    Id_Creador INT NULL,
    Id_Modificador INT NULL,
    CONSTRAINT UQ_TipoCatalogo_Catalogo UNIQUE (Id_Tipo_Catalogo, Catalogo)
);

CREATE TABLE Cls_Roles (  
    Id_Rol INT PRIMARY KEY IDENTITY(1,1),
    Nombre_Rol VARCHAR(80) NOT NULL UNIQUE,
    Descripcion VARCHAR(255),
    Fecha_Creacion DATETIME NOT NULL DEFAULT GETDATE(),
    Fecha_Modificacion DATETIME NOT NULL DEFAULT GETDATE(),
    Id_Creador INT NULL,
    Id_Modificador INT NULL,
    Activo BIT DEFAULT 1
);

CREATE TABLE Cls_Metodos_Pago (
    Id_Metodo_Pago INT PRIMARY KEY IDENTITY(1,1),
    Descripcion VARCHAR(50) NOT NULL, -- Efectivo, Tarjeta, etc.
    Id_Estado INT NOT NULL REFERENCES Cls_Estados(Id_Estado),
    Fecha_Creacion DATETIME DEFAULT GETDATE(),
    Fecha_Modificacion DATETIME DEFAULT GETDATE(),
    Id_Creador INT NULL,
    Id_Modificador INT NULL,
    Activo BIT DEFAULT 1
);

CREATE TABLE Cls_Tipo_Movimiento (
    Id_Tipo_Movimiento INT PRIMARY KEY IDENTITY(1,1),
    Descripcion VARCHAR(50) NOT NULL,
    Operacion VARCHAR(10) NOT NULL, -- 'Entrada' o 'Salida'
    Id_Estado INT NOT NULL REFERENCES Cls_Estados(Id_Estado),
    Fecha_Creacion DATETIME NOT NULL DEFAULT GETDATE(),
    Fecha_Modificacion DATETIME NOT NULL DEFAULT GETDATE(), 
    Id_Creador INT NULL, 
    Id_Modificador INT NULL, 
    Activo BIT DEFAULT 1
);

CREATE TABLE Tbl_Datos_Personales (  
    Id_Persona INT PRIMARY KEY IDENTITY(1,1),
    Primer_Nombre VARCHAR(80) NOT NULL,
    Segundo_Nombre VARCHAR(80),
    Primer_Apellido VARCHAR(80) NOT NULL,
    Segundo_Apellido VARCHAR(80),
    Id_Tipo_DNI INT REFERENCES Cls_Catalogos(Id_Catalogo),
    DNI VARCHAR(20) NOT NULL UNIQUE,
    Id_Genero INT REFERENCES Cls_Catalogos(Id_Catalogo),
    Id_Nacionalidad INT REFERENCES Cls_Catalogos(Id_Catalogo),
    Fecha_Creacion DATETIME NOT NULL DEFAULT GETDATE(),
    Fecha_Modificacion DATETIME NOT NULL DEFAULT GETDATE(),
    Id_Creador INT NULL,
    Id_Modificador INT NULL,
    Id_Estado INT NOT NULL REFERENCES Cls_Estados(Id_Estado)
);

CREATE TABLE Tbl_Usuarios ( 
    Id_Usuario INT PRIMARY KEY IDENTITY(1,1),
    Nombre_Usuario VARCHAR(100) NOT NULL UNIQUE,
    Contrasena VARCHAR(255) NOT NULL, 
    Id_Persona INT NOT NULL  REFERENCES Tbl_Datos_Personales(Id_Persona),
    Id_Rol INT NOT NULL REFERENCES Cls_Roles(Id_Rol),
    Fecha_Ultimo_Acceso DATETIME,
    Fecha_Creacion DATETIME NOT NULL DEFAULT GETDATE(),
    Fecha_Modificacion DATETIME NOT NULL DEFAULT GETDATE(),
    Id_Creador INT NULL, 
    Id_Modificador INT NULL,
    Id_Estado INT NOT NULL REFERENCES Cls_Estados(Id_Estado)
);

CREATE TABLE Tbl_Direcciones (
    Id_Direccion INT PRIMARY KEY IDENTITY(1,1),
    Id_Persona INT NOT NULL REFERENCES Tbl_Datos_Personales(Id_Persona), 
    Direccion_Completa VARCHAR(255) NOT NULL,
    Id_Tipo_Direccion INT REFERENCES Cls_Catalogos(Id_Catalogo),
    Fecha_Creacion DATETIME NOT NULL DEFAULT GETDATE(),
    Fecha_Modificacion DATETIME NOT NULL DEFAULT GETDATE(),
    Id_Creador INT NOT NULL REFERENCES Tbl_Usuarios(Id_Usuario),
    Id_Modificador INT NOT NULL REFERENCES Tbl_Usuarios(Id_Usuario),
    Activo BIT DEFAULT 1
);

CREATE TABLE Tbl_Telefonos (
    Id_Telefono INT PRIMARY KEY IDENTITY(1,1),
    Id_Persona INT NOT NULL REFERENCES Tbl_Datos_Personales(Id_Persona),
    Numero_Telefono VARCHAR(20) NOT NULL,
    Id_Tipo_Telefono INT REFERENCES Cls_Catalogos(Id_Catalogo),
    Fecha_Creacion DATETIME NOT NULL DEFAULT GETDATE(),
    Fecha_Modificacion DATETIME NOT NULL DEFAULT GETDATE(),
    Id_Creador INT NOT NULL REFERENCES Tbl_Usuarios(Id_Usuario),
    Id_Modificador INT NOT NULL REFERENCES Tbl_Usuarios(Id_Usuario),
    Activo BIT DEFAULT 1
);

CREATE TABLE Tbl_Correos (
    Id_Correo INT PRIMARY KEY IDENTITY(1,1),
    Id_Persona INT NOT NULL REFERENCES Tbl_Datos_Personales(Id_Persona),
    Direccion_Correo VARCHAR(100) NOT NULL,
    Id_Tipo_Correo INT REFERENCES Cls_Catalogos(Id_Catalogo),
    Fecha_Creacion DATETIME NOT NULL DEFAULT GETDATE(),
    Fecha_Modificacion DATETIME NOT NULL DEFAULT GETDATE(),
    Id_Creador INT NOT NULL REFERENCES Tbl_Usuarios(Id_Usuario),
    Id_Modificador INT NOT NULL REFERENCES Tbl_Usuarios(Id_Usuario),
    Activo BIT DEFAULT 1
);

CREATE TABLE Tbl_Cliente (
    Id_Cliente INT PRIMARY KEY IDENTITY(1,1),
    Id_Persona INT NOT NULL REFERENCES Tbl_Datos_Personales(Id_Persona),
    Id_Estado INT NOT NULL REFERENCES Cls_Estados(Id_Estado),
    Fecha_Creacion DATETIME NOT NULL DEFAULT GETDATE(),
    Fecha_Modificacion DATETIME NOT NULL DEFAULT GETDATE(),
    Id_Creador INT NOT NULL REFERENCES Tbl_Usuarios(Id_Usuario),
    Id_Modificador INT NOT NULL REFERENCES Tbl_Usuarios(Id_Usuario)
);

CREATE TABLE Tbl_Empleado (
    Id_Empleado INT PRIMARY KEY IDENTITY(1,1),
    Id_Persona INT NOT NULL UNIQUE REFERENCES Tbl_Datos_Personales(Id_Persona),
    Fecha_Contratacion DATE,
    Fecha_Despido Date,
    Id_Cargo INT REFERENCES Cls_Catalogos(Id_Catalogo),
    Id_Estado INT NOT NULL REFERENCES Cls_Estados(Id_Estado),
    Fecha_Creacion DATETIME NOT NULL DEFAULT GETDATE(),
    Fecha_Modificacion DATETIME NOT NULL DEFAULT GETDATE(),
    Id_Creador INT NOT NULL REFERENCES Tbl_Usuarios(Id_Usuario),
    Id_Modificador INT NOT NULL REFERENCES Tbl_Usuarios(Id_Usuario)
);

CREATE TABLE Tbl_Proveedor (
    Id_Proveedor INT PRIMARY KEY IDENTITY(1,1),
    Id_Persona INT NOT NULL UNIQUE REFERENCES Tbl_Datos_Personales(Id_Persona),
    FechaRegistro DATETIME NOT NULL DEFAULT GETDATE(),
    Fecha_Terminacion_Contrato Datetime,
    Id_Estado INT NOT NULL REFERENCES Cls_Estados(Id_Estado),
    Id_Creador INT NOT NULL REFERENCES Tbl_Usuarios(Id_Usuario),
    Id_Modificador INT NOT NULL REFERENCES Tbl_Usuarios(Id_Usuario)
);

CREATE TABLE Tbl_Categoria (
    Id_Categoria INT PRIMARY KEY IDENTITY(1,1),
    Nombre VARCHAR(50) NOT NULL,
    Fecha_Creacion DATETIME NOT NULL DEFAULT GETDATE(),
    Fecha_Modificacion DATETIME NOT NULL DEFAULT GETDATE(),
    Id_Estado INT NOT NULL REFERENCES Cls_Estados(Id_Estado),
    Id_Creador INT NOT NULL REFERENCES Tbl_Usuarios(Id_Usuario),
    Id_Modificador INT NOT NULL REFERENCES Tbl_Usuarios(Id_Usuario)
);

CREATE TABLE Cls_Marca (
    Id_Marca INT PRIMARY KEY IDENTITY(1,1),
    Nombre_Marca VARCHAR(100) NOT NULL,
    Id_Estado INT NOT NULL REFERENCES Cls_Estados(Id_Estado),
    Fecha_Creacion DATETIME NOT NULL DEFAULT GETDATE(),
    Fecha_Modificacion DATETIME NOT NULL DEFAULT GETDATE(),
    Id_Creador INT NOT NULL REFERENCES Tbl_Usuarios(Id_Usuario),
    Id_Modificador INT NOT NULL REFERENCES Tbl_Usuarios(Id_Usuario)
);

CREATE TABLE Cls_Modelo (
    Id_Modelo INT PRIMARY KEY IDENTITY(1,1),
    Nombre_Modelo VARCHAR(100) NOT NULL,
    Id_Estado INT NOT NULL REFERENCES Cls_Estados(Id_Estado),
    Fecha_Creacion DATETIME NOT NULL DEFAULT GETDATE(),
    Fecha_Modificacion DATETIME NOT NULL DEFAULT GETDATE(),
    Id_Creador INT NOT NULL REFERENCES Tbl_Usuarios(Id_Usuario),
    Id_Modificador INT NOT NULL REFERENCES Tbl_Usuarios(Id_Usuario)
);

CREATE TABLE Tbl_Marca_Modelo
(
    Id_Marca_Modelo INT PRIMARY KEY IDENTITY(1,1),
    Id_Marca INT REFERENCES Cls_Marca (Id_Marca),
    Id_Modelo INT REFERENCES Cls_Modelo (Id_Modelo),
    Fecha_Creacion DATETIME NOT NULL DEFAULT GETDATE(),
    Fecha_Modificacion DATETIME NOT NULL DEFAULT GETDATE(),
    Id_Creador INT NOT NULL REFERENCES Tbl_Usuarios(Id_Usuario),
    Id_Modificador INT NOT NULL REFERENCES Tbl_Usuarios(Id_Usuario),
    Id_Estado INT NOT NULL REFERENCES Cls_Estados(Id_Estado)
);

CREATE TABLE Tbl_Producto (
    Id_Producto INT PRIMARY KEY IDENTITY(1,1),
    Codigo VARCHAR(50) NOT NULL UNIQUE,
    Nombre VARCHAR(150) NOT NULL,
    Descripcion VARCHAR(250),
    Precio DECIMAL(12,2) NOT NULL, 
    Precio_Compra DECIMAL(18,2) NOT NULL DEFAULT 0, -- revisar esto tambien 
    Id_Marca_Modelo INT REFERENCES Tbl_Marca_Modelo(Id_Marca_Modelo),
    Id_Proveedor INT REFERENCES Tbl_Proveedor(Id_Proveedor), -- Revisar esto, no tiene sentido que se agregrue
    Id_Categoria INT REFERENCES Tbl_Categoria(Id_Categoria),
    Id_Estado INT NOT NULL REFERENCES Cls_Estados(Id_Estado),
    Fecha_Creacion DATETIME NOT NULL DEFAULT GETDATE(),
    Fecha_Modificacion DATETIME NOT NULL DEFAULT GETDATE(),
    Id_Creador INT NOT NULL REFERENCES Tbl_Usuarios(Id_Usuario),
    Id_Modificador INT NOT NULL REFERENCES Tbl_Usuarios(Id_Usuario)
);

CREATE TABLE Tbl_Bodega (
    Id_Bodega INT PRIMARY KEY IDENTITY(1,1),
    Id_Producto INT NOT NULL UNIQUE REFERENCES Tbl_Producto(Id_Producto),
    Cantidad INT NOT NULL DEFAULT 0, 
    Id_Estado INT NOT NULL REFERENCES Cls_Estados(Id_Estado),
    Fecha_Creacion DATETIME NOT NULL DEFAULT GETDATE(),
    Fecha_Modificacion DATETIME NOT NULL DEFAULT GETDATE(),
    Id_Creador INT NOT NULL REFERENCES Tbl_Usuarios(Id_Usuario),
    Id_Modificador INT NOT NULL REFERENCES Tbl_Usuarios(Id_Usuario)
);

CREATE TABLE Tbl_Ventas (
    Id_Venta INT PRIMARY KEY IDENTITY(1,1),
    Fecha DATETIME DEFAULT GETDATE(),
    Id_Cliente INT NOT NULL REFERENCES Tbl_Cliente(Id_Cliente),
    Id_Empleado INT REFERENCES Tbl_Empleado(Id_Empleado),
    Id_Metodo_Pago INT NULL REFERENCES Cls_Metodos_Pago(Id_Metodo_Pago), 
    Total DECIMAL(12,2) NOT NULL,
    Id_Estado INT NOT NULL REFERENCES Cls_Estados(Id_Estado),
    Fecha_Creacion DATETIME NOT NULL DEFAULT GETDATE(),
    Fecha_Modificacion DATETIME NOT NULL DEFAULT GETDATE(),
    Id_Creador INT NOT NULL REFERENCES Tbl_Usuarios(Id_Usuario),
    Id_Modificador INT NOT NULL REFERENCES Tbl_Usuarios(Id_Usuario)
);

CREATE TABLE Tbl_Detalle_Venta (
    Id_Detalle INT PRIMARY KEY IDENTITY(1,1),
    Id_Venta INT NOT NULL REFERENCES Tbl_Ventas(Id_Venta),
    Id_Producto INT NOT NULL REFERENCES Tbl_Producto(Id_Producto),
    Cantidad INT NOT NULL,
    Precio_Unitario_Al_Momento_Venta DECIMAL(12,2) NOT NULL,
    Subtotal DECIMAL(12,2) NOT NULL,
    Fecha_Creacion DATETIME NOT NULL DEFAULT GETDATE(),
    Fecha_Modificacion DATETIME NOT NULL DEFAULT GETDATE(),
    Id_Creador INT NOT NULL REFERENCES Tbl_Usuarios(Id_Usuario),
    Id_Modificador INT NOT NULL REFERENCES Tbl_Usuarios(Id_Usuario)
);

CREATE TABLE Tbl_Compra (
    Id_Compra INT PRIMARY KEY IDENTITY(1,1),
    Id_Proveedor INT NOT NULL REFERENCES Tbl_Proveedor(Id_Proveedor),
    Numero_Factura_Proveedor VARCHAR(50),
    Fecha_Compra DATE DEFAULT GETDATE(),
    Total_Compra DECIMAL(12,2) NOT NULL,
    Id_Estado INT NOT NULL REFERENCES Cls_Estados(Id_Estado),
    Fecha_Creacion DATETIME NOT NULL DEFAULT GETDATE(),
    Fecha_Modificacion DATETIME NOT NULL DEFAULT GETDATE(),
    Id_Creador INT NOT NULL REFERENCES Tbl_Usuarios(Id_Usuario),
    Id_Modificador INT NOT NULL REFERENCES Tbl_Usuarios(Id_Usuario)
);

CREATE TABLE Tbl_Detalle_Compra (
    Id_Detalle_Compra INT PRIMARY KEY IDENTITY(1,1),
    Id_Compra INT NOT NULL REFERENCES Tbl_Compra(Id_Compra) ON DELETE CASCADE,
    Id_Producto INT NOT NULL REFERENCES Tbl_Producto(Id_Producto),
    Cantidad INT NOT NULL,
    Precio_Unitario_Compra DECIMAL(12,2) NOT NULL,
    Subtotal_Compra DECIMAL(12,2) NOT NULL,
    Fecha_Creacion DATETIME NOT NULL DEFAULT GETDATE(),
    Fecha_Modificacion DATETIME NOT NULL DEFAULT GETDATE(),
    Id_Creador INT NOT NULL REFERENCES Tbl_Usuarios(Id_Usuario),
    Id_Modificador INT NOT NULL REFERENCES Tbl_Usuarios(Id_Usuario)
);

CREATE TABLE Tbl_Movimientos_Inventario (
    Id_Movimiento INT PRIMARY KEY IDENTITY(1,1),
    Id_Producto INT NOT NULL REFERENCES Tbl_Producto(Id_Producto),
    Id_Bodega INT NOT NULL REFERENCES Tbl_Bodega(Id_Bodega), 
    Id_Tipo_Movimiento INT NOT NULL REFERENCES Cls_Tipo_Movimiento(Id_Tipo_Movimiento),
    Cantidad INT NOT NULL,
    Stock_Anterior INT NOT NULL,
    Stock_Actual INT NOT NULL,
    Costo_Unitario DECIMAL(18,2) NOT NULL DEFAULT 0,
    Referencia VARCHAR(100) NULL,
    Observaciones VARCHAR(255) NULL,
    Fecha_Movimiento DATETIME NOT NULL DEFAULT GETDATE(),
    Id_Usuario_Responsable INT NOT NULL REFERENCES Tbl_Usuarios(Id_Usuario),
    Fecha_Creacion DATETIME DEFAULT GETDATE()
)

CREATE TABLE Tbl_Configuracion_Empresa (
    Id_Configuracion INT PRIMARY KEY IDENTITY(1,1),
    Nombre_Empresa VARCHAR(100) NOT NULL,
    RUC_No VARCHAR(50) NOT NULL,
    Direccion VARCHAR(255) NOT NULL,
    Telefono VARCHAR(20) NULL,
    Correo_Empresa VARCHAR(100) NULL,
    Ruta_Logo VARCHAR(255) NULL,
    Moneda_Simbolo VARCHAR(5) DEFAULT 'C$',
    Fecha_Modificacion DATETIME DEFAULT GETDATE(),
    Id_Modificador INT NULL 
);

GO

-- LISTA DE PODERES DISPONIBLES EN EL SISTEMA
CREATE TABLE Cls_Permisos (
    Id_Permiso INT IDENTITY(1,1) PRIMARY KEY,
    Nombre_Permiso VARCHAR(100) NOT NULL, -- Ej: "Ver Inventario"
    Codigo_Permiso VARCHAR(50) UNIQUE NOT NULL, -- Ej: "INV_READ", "INV_DELETE"
    Descripcion VARCHAR(255),
    Id_Estado INT DEFAULT 1
);


-- RELACIÓN: QUÉ PERMISOS TIENE CADA ROL
CREATE TABLE Tbl_Roles_Permisos (
    Id_Rol_Permiso INT IDENTITY(1,1) PRIMARY KEY,
    Id_Rol INT NOT NULL REFERENCES Cls_Roles(Id_Rol),
    Id_Permiso INT NOT NULL REFERENCES Cls_Permisos(Id_Permiso),
    Activo BIT DEFAULT 1,
    CONSTRAINT UQ_Rol_Permiso UNIQUE (Id_Rol, Id_Permiso)
);

select * from Tbl_Roles_Permisos





-- Esto agrega una columna "virtual" que se calcula sola basándose en el ID.

ALTER TABLE Tbl_Ventas
ADD Numero_Factura AS ('FAC-' + RIGHT('000000' + CAST(Id_Venta AS VARCHAR(10)), 6));
GO

-- Paso A: Primero aseguramos que el campo de factura no permita vacíos (Requisito técnico)
ALTER TABLE Tbl_Compra 
ALTER COLUMN Numero_Factura_Proveedor VARCHAR(50) NOT NULL;
GO

-- Paso B: Agregamos la restricción (Constraint)
-- Esto dice: "En la tabla Compras, la combinación (Proveedor + Factura) debe ser ÚNICA"
ALTER TABLE Tbl_Compra
ADD CONSTRAINT UQ_Compra_Proveedor_Factura UNIQUE (Id_Proveedor, Numero_Factura_Proveedor);
GO

ALTER TABLE Tbl_Usuarios
ADD CONSTRAINT UQ_Usuario_Persona UNIQUE (Id_Persona);

ALTER TABLE Tbl_Detalle_Venta
ADD Id_Estado INT NOT NULL DEFAULT 1 REFERENCES Cls_Estados(Id_Estado);