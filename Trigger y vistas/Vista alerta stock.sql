USE NicaTek;
GO

CREATE OR ALTER VIEW Vw_Alertas_Stock_Bajo
AS
SELECT 
    bp.Id_Bodega_Producto,
    bp.Id_Bodega,
    b.Nombre_Bodega AS Bodega,
    bp.Id_Producto,
    p.Nombre AS Producto,
    p.Codigo,
    bp.Cantidad AS Stock_Actual,
    p.Precio_Compra AS Costo_Reposicion
FROM Tbl_Bodega_Producto bp
INNER JOIN Tbl_Producto p ON bp.Id_Producto = p.Id_Producto
INNER JOIN Tbl_Bodega b ON bp.Id_Bodega = b.Id_Bodega
WHERE bp.Cantidad <= 5
GO

