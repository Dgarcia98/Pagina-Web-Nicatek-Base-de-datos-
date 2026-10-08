CREATE OR ALTER TRIGGER tr_ActualizarCosto_Producto
ON Tbl_Movimientos_Inventario
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE P
    SET 
        P.Precio_Compra = i.Costo_Unitario, -- Actualizamos al último costo ingresado
        P.Fecha_Modificacion = GETDATE(),
        P.Id_Modificador = i.Id_Usuario_Responsable 
    FROM 
        Tbl_Producto P
    INNER JOIN 
        inserted i ON P.Id_Producto = i.Id_Producto
    INNER JOIN 
        Cls_Tipo_Movimiento tm ON i.Id_Tipo_Movimiento = tm.Id_Tipo_Movimiento
    WHERE 
        tm.Operacion = 'SUMA'      -- CORREGIDO: En tu tabla usas 'SUMA'
        AND i.Costo_Unitario > 0;  -- Excelente validación de seguridad
END
GO