CREATE OR ALTER TRIGGER tr_ActualizarStock_Desde_Kardex
ON Tbl_Movimientos_Inventario
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Actualiza el stock físico en la tabla Bodega
    UPDATE B
    SET 
        B.Cantidad = B.Cantidad + (
            CASE 
                WHEN tm.Operacion = 'SUMA' THEN i.Cantidad
                WHEN tm.Operacion = 'RESTA' THEN (i.Cantidad * -1)
                ELSE 0 
            END
        ),
        B.Fecha_Modificacion = GETDATE()
    FROM Tbl_Bodega B
    INNER JOIN inserted i ON B.Id_Bodega = i.Id_Bodega
    INNER JOIN Cls_Tipo_Movimiento tm ON i.Id_Tipo_Movimiento = tm.Id_Tipo_Movimiento;
END
GO



