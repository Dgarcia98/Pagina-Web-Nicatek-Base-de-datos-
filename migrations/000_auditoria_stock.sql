/* =====================================================================
   000 - AUDITORIA DE STOCK (SOLO LECTURA - no modifica nada)
   ---------------------------------------------------------------------
   Ejecutar ESTE script ANTES que 001 y 002.
   Sirve para saber cuanto inventario esta descuadrado hoy, por culpa de:
     - Anulaciones de compra que nunca descontaron stock
     - Movimientos insertados sin Id_Bodega_Producto
   Guarda los resultados: despues de aplicar 002 los vuelves a correr
   para confirmar que ya no crece el descuadre.
   ===================================================================== */
USE NicaTek;
GO

SET NOCOUNT ON;

PRINT '=== 1. Trigger de stock actualmente activo ==========================';
SELECT  t.name                AS Trigger_Name,
        OBJECT_NAME(t.parent_id) AS Tabla,
        t.is_disabled,
        CASE WHEN m.definition LIKE '%Tbl_Bodega_Producto%' THEN 'NUEVO (multi-bodega)'
             WHEN m.definition LIKE '%Tbl_Bodega%'          THEN 'VIEJO (una bodega)'
             ELSE 'desconocido' END AS Version
FROM sys.triggers t
JOIN sys.sql_modules m ON m.object_id = t.object_id
WHERE t.name IN ('tr_ActualizarStock_Desde_Kardex',
                 'tr_EvitarStockNegativo',
                 'tr_ActualizarCosto_Producto');

PRINT '';
PRINT '=== 2. Movimientos huerfanos (sin Id_Bodega_Producto) ===============';
PRINT '    Estos NUNCA movieron stock aunque quedaron en el kardex.';
SELECT  COUNT(*)                    AS Movimientos_Sin_Vinculo,
        MIN(Fecha_Movimiento)       AS Desde,
        MAX(Fecha_Movimiento)       AS Hasta
FROM Tbl_Movimientos_Inventario
WHERE Id_Bodega_Producto IS NULL;

SELECT TOP 50
        m.Id_Movimiento, m.Id_Producto, p.Nombre AS Producto,
        m.Id_Bodega, tm.Descripcion AS Tipo_Movimiento, tm.Operacion,
        m.Cantidad, m.Referencia, m.Fecha_Movimiento
FROM Tbl_Movimientos_Inventario m
LEFT JOIN Tbl_Producto          p  ON p.Id_Producto        = m.Id_Producto
LEFT JOIN Cls_Tipo_Movimiento   tm ON tm.Id_Tipo_Movimiento = m.Id_Tipo_Movimiento
WHERE m.Id_Bodega_Producto IS NULL
ORDER BY m.Fecha_Movimiento DESC;

PRINT '';
PRINT '=== 3. DESCUADRE: stock de la tabla vs. suma del kardex =============';
PRINT '    Diferencia <> 0 significa que la tabla y el historial no coinciden.';
;WITH Kardex AS (
    SELECT  m.Id_Bodega_Producto,
            SUM(CASE WHEN tm.Operacion IN ('SUMA','Entrada')  THEN  m.Cantidad
                     WHEN tm.Operacion IN ('RESTA','Salida')  THEN -m.Cantidad
                     ELSE 0 END) AS Stock_Kardex
    FROM Tbl_Movimientos_Inventario m
    JOIN Cls_Tipo_Movimiento tm ON tm.Id_Tipo_Movimiento = m.Id_Tipo_Movimiento
    WHERE m.Id_Bodega_Producto IS NOT NULL
    GROUP BY m.Id_Bodega_Producto
)
SELECT  bp.Id_Bodega_Producto,
        b.Nombre_Bodega,
        p.Codigo,
        p.Nombre                        AS Producto,
        bp.Cantidad                     AS Stock_En_Tabla,
        ISNULL(k.Stock_Kardex, 0)       AS Stock_Segun_Kardex,
        bp.Cantidad - ISNULL(k.Stock_Kardex, 0) AS Diferencia
FROM Tbl_Bodega_Producto bp
JOIN Tbl_Bodega    b ON b.Id_Bodega   = bp.Id_Bodega
JOIN Tbl_Producto  p ON p.Id_Producto = bp.Id_Producto
LEFT JOIN Kardex   k ON k.Id_Bodega_Producto = bp.Id_Bodega_Producto
WHERE bp.Cantidad <> ISNULL(k.Stock_Kardex, 0)
ORDER BY ABS(bp.Cantidad - ISNULL(k.Stock_Kardex, 0)) DESC;

PRINT '';
PRINT '=== 4. Stock negativo (no deberia existir nunca) ====================';
SELECT  bp.Id_Bodega_Producto, b.Nombre_Bodega, p.Codigo, p.Nombre, bp.Cantidad
FROM Tbl_Bodega_Producto bp
JOIN Tbl_Bodega   b ON b.Id_Bodega   = bp.Id_Bodega
JOIN Tbl_Producto p ON p.Id_Producto = bp.Id_Producto
WHERE bp.Cantidad < 0;

PRINT '';
PRINT '=== 5. Compras anuladas y si descontaron stock ======================';
PRINT '    Movimientos_Generados = 0 -> la anulacion no toco el inventario.';
SELECT  c.Id_Compra,
        c.Numero_Factura_Proveedor,
        c.Fecha_Modificacion            AS Fecha_Anulacion,
        c.Total_Compra,
        (SELECT COUNT(*) FROM Tbl_Movimientos_Inventario m
          WHERE m.Referencia LIKE 'Anulaci%Compra #' + CAST(c.Id_Compra AS VARCHAR)
            AND m.Id_Bodega_Producto IS NOT NULL) AS Movimientos_Efectivos
FROM Tbl_Compra c
WHERE c.Id_Estado = 3
ORDER BY c.Fecha_Modificacion DESC;

PRINT '';
PRINT '=== 6. Ventas cuyo total NO cuadra con la suma de sus detalles ======';
PRINT '    Sintoma tipico de venta a medio guardar (insercion no atomica).';
SELECT  v.Id_Venta,
        v.Numero_Factura,
        es.Estado,
        v.Total                                  AS Total_Cabecera,
        ISNULL(SUM(dv.Subtotal), 0)              AS Suma_Detalles,
        v.Total - ISNULL(SUM(dv.Subtotal), 0)    AS Diferencia,
        COUNT(dv.Id_Detalle)                     AS Lineas
FROM Tbl_Ventas v
JOIN Cls_Estados es ON es.Id_Estado = v.Id_Estado
LEFT JOIN Tbl_Detalle_Venta dv
       ON dv.Id_Venta = v.Id_Venta AND dv.Id_Estado <> 3
WHERE v.Id_Estado <> 3
GROUP BY v.Id_Venta, v.Numero_Factura, es.Estado, v.Total
HAVING v.Total <> ISNULL(SUM(dv.Subtotal), 0)
ORDER BY ABS(v.Total - ISNULL(SUM(dv.Subtotal), 0)) DESC;

PRINT '';
PRINT '=== 7. Ventas "Completado" sin ninguna linea de detalle =============';
SELECT  v.Id_Venta, v.Numero_Factura, v.Fecha, v.Total, v.Id_Creador
FROM Tbl_Ventas v
WHERE v.Id_Estado = 4
  AND NOT EXISTS (SELECT 1 FROM Tbl_Detalle_Venta dv WHERE dv.Id_Venta = v.Id_Venta)
ORDER BY v.Fecha DESC;

PRINT '';
PRINT '=== 8. Precios de venta por debajo del costo (posible manipulacion) =';
SELECT  dv.Id_Detalle, dv.Id_Venta, p.Codigo, p.Nombre,
        dv.Precio_Unitario_Al_Momento_Venta AS Precio_Cobrado,
        p.Precio                            AS Precio_Lista,
        p.Precio_Compra                     AS Costo
FROM Tbl_Detalle_Venta dv
JOIN Tbl_Producto p ON p.Id_Producto = dv.Id_Producto
WHERE dv.Precio_Unitario_Al_Momento_Venta < p.Precio_Compra
   OR dv.Precio_Unitario_Al_Momento_Venta <= 0
ORDER BY dv.Id_Venta DESC;
GO
