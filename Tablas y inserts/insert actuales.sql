USE NicaTek;
GO

INSERT INTO Cls_Estados (Estado, Id_Creador, Id_Modificador, Activo) VALUES 
('Activo', NULL, NULL, 1),
('Inactivo', NULL, NULL, 1),
('Anulado', NULL, NULL, 1);
GO

INSERT INTO Cls_Roles (Nombre_Rol, Descripcion, Id_Creador, Id_Modificador, Activo) VALUES 
('Administrador', 'Acceso total al sistema', NULL, NULL, 1),
('Empleado', 'Acceso limitado', NULL, NULL, 1);
GO

-- 1. CREAMOS LOS PERMISOS (LOS PODERES)
INSERT INTO Cls_Permisos (Nombre_Permiso, Codigo_Permiso, Descripcion) VALUES
('Ver Inventario', 'INV_READ', 'Permite ver la lista de productos'),
('Crear Producto', 'INV_CREATE', 'Permite agregar nuevos productos'),
('Editar Producto', 'INV_UPDATE', 'Permite modificar productos existentes'),
('Eliminar Producto', 'INV_DELETE', 'Permite borrar productos (Peligroso)'),
('Realizar Venta', 'POS_SALE', 'Permite acceder a la pantalla de ventas'),
('Ver Reportes', 'RPT_VIEW', 'Acceso a reportes financieros'),
('Gestionar Usuarios', 'USR_MANAGE', 'Crear o bloquear usuarios');

-- 2. ASIGNAMOS PERMISOS A LOS ROLES

-- ROL 1: ADMINISTRADOR (Tiene TODO)
-- Le damos del permiso 1 al 7
INSERT INTO Tbl_Roles_Permisos (Id_Rol, Id_Permiso)
SELECT 1, Id_Permiso FROM Cls_Permisos; 

-- ROL 2: EMPLEADO (Restringido)
-- Solo puede: Ver Inventario (1), Realizar Venta (5)
-- NO PUEDE: Editar, Eliminar, Ver Reportes ni Gestionar Usuarios.
INSERT INTO Tbl_Roles_Permisos (Id_Rol, Id_Permiso) VALUES
(2, 1), -- INV_READ
(2, 5); -- POS_SALE
GO

INSERT INTO Cls_Tipo_Catalogos (Tipo_Catalogo, Id_Creador, Id_Modificador, Activo) VALUES 
('Género', NULL, NULL, 1),      
('Tipo DNI', NULL, NULL, 1),     
('Nacionalidad', NULL, NULL, 1), 
('Cargo', NULL, NULL, 1),        
('Tipo Correo', NULL, NULL, 1), 
('Tipo Teléfono', NULL, NULL, 1),
('Tipo Dirección', NULL, NULL, 1);
GO

INSERT INTO Cls_Catalogos (Id_Tipo_Catalogo, Catalogo, Id_Creador, Id_Modificador, Activo) VALUES 
(1, 'Masculino', NULL, NULL, 1),      
(1, 'Femenino', NULL, NULL, 1),       
(1, 'Otro', NULL, NULL, 1),            
(2, 'Cédula', NULL, NULL, 1),         
(2, 'Pasaporte', NULL, NULL, 1),      
(3, 'Nicaragüense', NULL, NULL, 1),   
(3, 'Costarricense', NULL, NULL, 1),  
(4, 'Vendedor', NULL, NULL, 1),       
(4, 'Soporte Técnico', NULL, NULL, 1),
(5, 'Institucional', NULL, NULL, 1),  
(5, 'Personal', NULL, NULL, 1),       
(5, 'Trabajo', NULL, NULL, 1),        
(6, 'Móvil', NULL, NULL, 1),          
(6, 'Fijo', NULL, NULL, 1),           
(6, 'Emergencia', NULL, NULL, 1),     
(7, 'Domicilio', NULL, NULL, 1);      
GO

INSERT INTO Cls_Tipo_Movimiento (Descripcion, Operacion, Id_Estado, Id_Creador, Id_Modificador) VALUES 
('Compra a Proveedor', 'SUMA', 1, NULL, NULL),      
('Venta a Cliente', 'RESTA', 1, NULL, NULL),        
('Devolución de Cliente', 'SUMA', 1, NULL, NULL),   
('Devolución a Proveedor', 'RESTA', 1, NULL, NULL),
('Anulación de Venta', 'SUMA', 1, NULL, NULL),      
('Ajuste de Inventario (+)', 'SUMA', 1, NULL, NULL),
('Ajuste de Inventario (-)', 'RESTA', 1, NULL, NULL),
('Inventario Inicial', 'SUMA', 1, NULL, NULL);      
GO

INSERT INTO Cls_Metodos_Pago (Descripcion, Id_Estado) VALUES 
('Efectivo', 1), ('Tarjeta de Crédito', 1), ('Tarjeta de Débito', 1), ('Transferencia Bancaria', 1);
GO

INSERT INTO Tbl_Datos_Personales (Primer_Nombre, Primer_Apellido, Id_Tipo_DNI, DNI, Id_Genero, Id_Nacionalidad, Id_Creador, Id_Modificador, Id_Estado)
VALUES ('Admin', 'NicaTek', 4, 'ADM001', 2, 6, NULL, NULL, 1);
GO

-- LOS INSERT DE USUARIOS SE HARAN DESDE EL SWAGGER, SOLO CREAR LAS PERSONAS 

INSERT INTO Tbl_Datos_Personales (Primer_Nombre, Segundo_Nombre, Primer_Apellido, Segundo_Apellido, Id_Tipo_DNI, DNI, Id_Genero, Id_Nacionalidad, Id_Creador, Id_Modificador, Id_Estado)
VALUES 
('Carlos', NULL, 'Ramirez', NULL, 4, 'Emp001', 1, 6, 1, 1, 1),
('Ana', NULL, 'Perez', NULL, 4, 'Emp002', 2, 7, 1, 1, 1),    
('Mario', NULL, 'Gonzalez', NULL, 4, 'Emp003', 1, 6, 1, 1, 1),
('Laura', NULL, 'Mendoza', NULL, 4, 'Emp004', 2, 7, 1, 1, 1), 
('Daniel', NULL, 'Vargas', NULL, 4, 'Emp005', 1, 6, 1, 1, 1); 
GO

INSERT INTO Tbl_Empleado (Id_Persona, Fecha_Contratacion, Fecha_Despido, Id_Cargo, Id_Estado, Id_Creador, Id_Modificador)
VALUES
(2, '2022-01-10', NULL, 8, 1, 1, 1), 
(3, '2022-03-15', NULL, 8, 1, 1, 1), 
(4, '2023-07-01', NULL, 8, 1, 1, 1), 
(5, '2023-09-20', NULL, 8, 1, 1, 1), 
(6, '2024-02-05', NULL, 8, 1, 1, 1); 
GO

INSERT INTO Tbl_Datos_Personales (Primer_Nombre, Segundo_Nombre, Primer_Apellido, Segundo_Apellido, Id_Tipo_DNI, DNI, Id_Genero, Id_Nacionalidad, Id_Creador, Id_Modificador, Id_Estado)
VALUES 
('Jorge', NULL, 'Morales', 'Sánchez', 4, 'CLI001', 3, 6, 1, 1, 1), 
('Carla', 'María', 'Zamora', NULL, 4, 'CLI002', 2, 7, 1, 1, 1),    
('Luis', NULL, 'Cruz', 'Delgado', 4, 'CLI003', 3, 6, 1, 1, 1),      
('Fernanda', NULL, 'Solís', 'Martínez', 4, 'CLI004', 2, 7, 1, 1, 1),
('Andrés', NULL, 'Chávez', NULL, 4, 'CLI005', 3, 6, 1, 1, 1),
('Ricardo', NULL, 'Gutiérrez', 'López', 4, 'PROV001', 1, 6, 1, 1, 1),  
('Sofía', 'Elena', 'Martínez', 'Castillo', 4, 'PROV002', 2, 7, 1, 1, 1),
('Héctor', NULL, 'Ramírez', 'Pineda', 4, 'PROV003', 1, 6, 1, 1, 1),    
('Verónica', NULL, 'Herrera', 'Mendoza', 4, 'PROV004', 2, 7, 1, 1, 1),  
('Esteban', 'Alonso', 'Ríos', 'Navarro', 4, 'PROV005', 1, 6, 1, 1, 1);  
GO

INSERT INTO Tbl_Cliente (Id_Persona, Id_Estado, Id_Creador, Id_Modificador)
VALUES 
(9, 1, 1, 1),   
(10, 1, 1, 1),  
(11, 1, 1, 1),  
(12, 1, 1, 1),  
(13, 1, 1, 1);  
GO

INSERT INTO Tbl_Proveedor (Id_Persona, Fecha_Terminacion_Contrato, Id_Estado, Id_Creador, Id_Modificador)
VALUES 
(14, NULL, 1, 1, 1), 
(15, NULL, 1, 1, 1), 
(16, NULL, 1, 1, 1), 
(17, NULL, 1, 1, 1), 
(18, NULL, 1, 1, 1); 
GO

INSERT INTO Tbl_Telefonos (Id_Persona, Numero_Telefono, Id_Tipo_Telefono, Id_Creador, Id_Modificador, Activo) VALUES
(1, '8888-0000', 13, 1, 1, 1),
(2, '8811-1111', 13, 1, 1, 1), (3, '8822-2222', 13, 1, 1, 1),
(4, '8833-3333', 13, 1, 1, 1), (5, '8844-4444', 13, 1, 1, 1), (6, '8855-5555', 13, 1, 1, 1),
(9, '7711-0001', 13, 1, 1, 1),  
(10, '7722-0002', 13, 1, 1, 1), 
(11, '7733-0003', 13, 1, 1, 1), 
(12, '7744-0004', 13, 1, 1, 1), 
(13, '7755-0005', 13, 1, 1, 1), 
(14, '2222-1001', 14, 1, 1, 1), 
(15, '2222-1002', 14, 1, 1, 1), 
(16, '2222-1003', 14, 1, 1, 1), 
(17, '2222-1004', 14, 1, 1, 1), 
(18, '2222-1005', 14, 1, 1, 1); 
GO

INSERT INTO Tbl_Correos (Id_Persona, Direccion_Correo, Id_Tipo_Correo, Id_Creador, Id_Modificador, Activo) VALUES
(1, 'admin@nicatek.com', 10, 1, 1, 1),
(2, 'carlos.ramirez@nicatek.com', 12, 1, 1, 1), 
(3, 'ana.perez@nicatek.com', 12, 1, 1, 1),
(4, 'mario.gonzalez@nicatek.com', 12, 1, 1, 1), 
(5, 'laura.mendoza@nicatek.com', 12, 1, 1, 1), 
(6, 'daniel.vargas@nicatek.com', 12, 1, 1, 1),
(9, 'jorge.morales@gmail.com', 11, 1, 1, 1), 
(10, 'carla.zamora@hotmail.com', 11, 1, 1, 1),
(11, 'luis.cruz@yahoo.com', 11, 1, 1, 1), 
(12, 'fernanda.solis@gmail.com', 11, 1, 1, 1), 
(13, 'andres.chavez@outlook.com', 11, 1, 1, 1),
(14, 'ventas@hp_distribucion.com', 12, 1, 1, 1), 
(15, 'contacto@dell_latam.com', 12, 1, 1, 1),
(16, 'soporte@lenovo_ni.com', 12, 1, 1, 1), 
(17, 'info@apple_reseller.com', 12, 1, 1, 1), 
(18, 'b2b@samsung_corp.com', 12, 1, 1, 1);
GO

INSERT INTO Tbl_Direcciones (Id_Persona, Direccion_Completa, Id_Tipo_Direccion, Id_Creador, Id_Modificador, Activo) VALUES
(1, 'Oficinas Centrales Nicatek, Managua', 16, 1, 1, 1),
(2, 'Bello Horizonte, Casa #50', 16, 1, 1, 1),
(3, 'Carretera Masaya km 10', 16, 1, 1, 1),
(4, 'Ciudad Jardín, Bloque C', 16, 1, 1, 1),
(5, 'Linda Vista, Casa #22', 16, 1, 1, 1),
(6, 'Altagracia, De la racachaca 2 abajo', 16, 1, 1, 1),
(9, 'Villa Fontana, Casa #88', 16, 1, 1, 1),
(10, 'Altamira D´este #12', 16, 1, 1, 1),
(11, 'Los Robles, Casa #5', 16, 1, 1, 1),
(12, 'Carretera Norte km 5', 16, 1, 1, 1),
(13, 'Batahola Sur', 16, 1, 1, 1),
(14, 'Oficinas HP, Edificio Pellas', 16, 1, 1, 1),
(15, 'Bodegas Dell, Zona Franca', 16, 1, 1, 1),
(16, 'Centro Logístico Lenovo', 16, 1, 1, 1),
(17, 'iStore, Galería Sto Domingo', 16, 1, 1, 1),
(18, 'Samsung Store, Metrocentro', 16, 1, 1, 1);
GO

INSERT INTO Tbl_Categoria (Nombre, Id_Estado, Id_Creador, Id_Modificador) VALUES
('Laptops', 1, 1, 1), ('Teléfonos Inteligentes', 1, 1, 1), ('Monitores', 1, 1, 1),
('Impresoras', 1, 1, 1), ('Teclados y Ratones', 1, 1, 1), ('Accesorios', 1, 1, 1),
('Tabletas', 1, 1, 1), ('Componentes', 1, 1, 1), ('Almacenamiento', 1, 1, 1), ('Redes', 1, 1, 1);
GO

INSERT INTO Cls_Marca (Nombre_Marca, Id_Estado, Id_Creador, Id_Modificador) VALUES
('HP', 1, 1, 1), ('Dell', 1, 1, 1), ('Lenovo', 1, 1, 1), ('Apple', 1, 1, 1),
('Samsung', 1, 1, 1), ('Asus', 1, 1, 1), ('Acer', 1, 1, 1), ('Xiaomi', 1, 1, 1),
('Logitech', 1, 1, 1), ('Kingston', 1, 1, 1);
GO

INSERT INTO Cls_Modelo (Nombre_Modelo, Id_Estado, Id_Creador, Id_Modificador) VALUES
('MacBook Air M2', 1, 1, 1), ('Dell XPS 13', 1, 1, 1), ('ThinkPad X1 Carbon', 1, 1, 1),
('Pavilion 15', 1, 1, 1), ('Galaxy S24', 1, 1, 1), ('iPhone 15 Pro', 1, 1, 1),
('Redmi Note 13', 1, 1, 1), ('ROG Zephyrus G14', 1, 1, 1), ('Nitro 5', 1, 1, 1),
('MX Master 3S', 1, 1, 1);
GO

INSERT INTO Tbl_Marca_Modelo (Id_Marca, Id_Modelo, Id_Creador, Id_Modificador, Id_Estado) VALUES
(4, 1, 1, 1, 1), (2, 2, 1, 1, 1), (3, 3, 1, 1, 1), (1, 4, 1, 1, 1), (5, 5, 1, 1, 1),
(4, 6, 1, 1, 1), (8, 7, 1, 1, 1), (6, 8, 1, 1, 1), (7, 9, 1, 1, 1), (9, 10, 1, 1, 1);
GO

INSERT INTO Tbl_Producto (Codigo, Nombre, Descripcion, Precio, Id_Marca_Modelo, Id_Proveedor, Id_Categoria, Id_Estado, Id_Creador, Id_Modificador) VALUES
('LP-AIR-M2', 'MacBook Air M2', 'Laptop Apple M2', 1200.00, 1, 8, 1, 1, 1, 1),        
('LP-XPS-13', 'Dell XPS 13', 'Laptop Dell i7', 1500.00, 2, 9, 1, 1, 1, 1),            
('LP-THINKX1', 'ThinkPad X1', 'Laptop Lenovo', 1800.00, 3, 10, 1, 1, 1, 1),           
('LP-PAV15', 'HP Pavilion 15', 'Laptop HP', 850.00, 4, 11, 1, 1, 1, 1),               
('TM-GS24', 'Samsung Galaxy S24', 'Teléfono S24', 999.00, 5, 12, 2, 1, 1, 1),         
('TM-IP15P', 'iPhone 15 Pro', 'Teléfono Apple', 1200.00, 6, 8, 2, 1, 1, 1),           
('TM-XRN13', 'Xiaomi Redmi 13', 'Teléfono Xiaomi', 299.00, 7, 9, 2, 1, 1, 1),         
('LP-ROG14', 'Asus ROG G14', 'Laptop Gamer', 1700.00, 8, 10, 1, 1, 1, 1),             
('LP-ACN5', 'Acer Nitro 5', 'Laptop Gamer', 900.00, 9, 11, 1, 1, 1, 1),               
('AC-MX3S', 'Logitech MX 3S', 'Mouse Pro', 99.00, 10, 12, 5, 1, 1, 1);                
GO

INSERT INTO Tbl_Bodega (Id_Producto, Cantidad, Id_Estado, Id_Creador, Id_Modificador) VALUES
(1, 10, 1, 1, 1), (2, 10, 1, 1, 1), (3, 10, 1, 1, 1), (4, 10, 1, 1, 1), (5, 10, 1, 1, 1),
(6, 10, 1, 1, 1), (7, 10, 1, 1, 1), (8, 10, 1, 1, 1), (9, 10, 1, 1, 1), (10, 20, 1, 1, 1);
GO

INSERT INTO Tbl_Movimientos_Inventario 
(Id_Producto, Id_Bodega, Id_Tipo_Movimiento, Cantidad, Stock_Anterior, Stock_Actual, Costo_Unitario, Referencia, Observaciones, Id_Usuario_Responsable)
VALUES
(1, 1, 8, 10, 0, 10, 1000.00, 'INICIO', 'Inventario Inicial', 1),
(2, 2, 8, 10, 0, 10, 1200.00, 'INICIO', 'Inventario Inicial', 1),
(3, 3, 8, 10, 0, 10, 1400.00, 'INICIO', 'Inventario Inicial', 1),
(4, 4, 8, 10, 0, 10, 700.00,  'INICIO', 'Inventario Inicial', 1),
(5, 5, 8, 10, 0, 10, 850.00,  'INICIO', 'Inventario Inicial', 1),
(6, 6, 8, 10, 0, 10, 1000.00, 'INICIO', 'Inventario Inicial', 1),
(7, 7, 8, 10, 0, 10, 200.00,  'INICIO', 'Inventario Inicial', 1),
(8, 8, 8, 10, 0, 10, 1300.00, 'INICIO', 'Inventario Inicial', 1),
(9, 9, 8, 10, 0, 10, 750.00,  'INICIO', 'Inventario Inicial', 1),
(10, 10, 8, 20, 0, 20, 50.00, 'INICIO', 'Inventario Inicial', 1);
GO

select * from Tbl_Ventas

INSERT INTO Tbl_Compra (Id_Proveedor, Numero_Factura_Proveedor, Fecha_Compra, Total_Compra, Id_Estado, Id_Creador, Id_Modificador) 
VALUES (8, 'FAC-0001', GETDATE(), 1500.00, 1, 1, 1);

INSERT INTO Tbl_Detalle_Compra (Id_Compra, Id_Producto, Cantidad, Precio_Unitario_Compra, Subtotal_Compra, Id_Creador, Id_Modificador) 
VALUES (IDENT_CURRENT('Tbl_Compra'), 1, 10, 150.00, 1500.00, 1, 1);
GO

-- VENTA DE PRUEBA
INSERT INTO Tbl_Ventas (Fecha, Id_Cliente, Id_Empleado, Total, Id_Estado, Id_Creador, Id_Modificador) VALUES
('20250601', 11, 3, 2499.99, 1, 1, 1);

-- Usamos IDENT_CURRENT para agarrar automaticamente el ID de la venta recien creada
INSERT INTO Tbl_Detalle_Venta (Id_Venta, Id_Producto, Cantidad, Precio_Unitario_Al_Momento_Venta, Subtotal, Id_Creador, Id_Modificador) VALUES
(IDENT_CURRENT('Tbl_Ventas'), 1, 1, 1200.00, 1200.00, 1, 1);
GO

INSERT INTO Tbl_Configuracion_Empresa (Nombre_Empresa, RUC_No, Direccion, Telefono, Correo_Empresa, Moneda_Simbolo) VALUES 
('Nicatek S.A.', 'J031000000000', 'Managua, Nicaragua', '2222-5555', 'contacto@Nicatek.ni', 'C$');
GO


