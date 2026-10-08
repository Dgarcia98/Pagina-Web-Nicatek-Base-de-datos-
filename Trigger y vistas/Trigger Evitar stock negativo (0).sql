CREATE TRIGGER tr_EvitarStockNegativo
ON Tbl_Bodega
AFTER UPDATE, INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted WHERE Cantidad < 0)
    BEGIN
        RAISERROR ('STOCK INSUFICIENTE: No se puede realizar la venta porque el inventario en Bodega quedaría en negativo.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END
GO
