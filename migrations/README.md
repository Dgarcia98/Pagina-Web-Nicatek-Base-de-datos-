# Migraciones de base de datos

Scripts numerados, en orden. Cada uno es idempotente: se puede volver a
correr sin romper nada.

Antes de esto había dos carpetas con versiones distintas del mismo SP
(`DB NicaTek/Store Procedure/` y `Nuevos sp/`), con nombres como
`COMPRAS SP (REVISAR ESTA BUENA SI.sql`. No había forma de saber qué estaba
realmente desplegado en Azure. **Esta carpeta es ahora la única fuente de
verdad**; las otras dos quedan como referencia histórica.

## Orden de ejecución

| # | Archivo | Qué hace | ¿Modifica datos? |
|---|---------|----------|------------------|
| 000 | `000_auditoria_stock.sql` | Diagnóstico: cuánto inventario está descuadrado hoy | No, solo lee |
| 001 | `001_indices.sql` | Crea los ~22 índices que faltaban | No |
| 002 | `002_unificar_stock.sql` | Un solo mecanismo de stock; corrige la anulación de compra | Cambia SPs y triggers, no filas |
| 003 | `003_registro_transaccional.sql` | `sp_Venta_Registrar`, `sp_Compra_Registrar`, dashboard, permisos | Solo crea objetos |

```sql
-- En SSMS o Azure Data Studio, conectado a la base Nicatek:
:r 000_auditoria_stock.sql      -- guardá los resultados
:r 001_indices.sql
:r 002_unificar_stock.sql
:r 003_registro_transaccional.sql
:r 000_auditoria_stock.sql      -- comparar contra la primera corrida
```

> **Correr 000 primero y guardar el resultado.** Es la foto del descuadre
> actual. Después de 002 el descuadre deja de crecer, pero el que ya existe
> no se corrige solo: hay que hacer un ajuste de inventario manual.

## El bug principal que corrige 002

`sp_Tbl_Compra` modo `DEL` insertaba el movimiento de inventario **sin**
`Id_Bodega_Producto`. El trigger empareja por esa columna, así que con NULL
no encontraba nada y **el stock nunca bajaba**: la compra quedaba anulada
pero la mercadería seguía contada en bodega.

Convivían tres mecanismos distintos para mover stock:

| Operación | Antes | Ahora |
|---|---|---|
| Detalle de compra (alta) | Solo movimiento → trigger | Igual (era el correcto) |
| Detalle de venta (alta) | `UPDATE` manual **+** movimiento sin vínculo | Solo movimiento |
| Anular venta | `UPDATE` manual **+** movimiento sin vínculo | Solo movimiento |
| Anular compra | Movimiento sin vínculo → **no descontaba** | Solo movimiento |

Los dos del medio "funcionaban" por accidente: el trigger no emparejaba el
NULL, así que no duplicaba el descuento. El día que alguien completara ese
campo — lo correcto para que el kardex sirva — el stock se habría movido el
doble.

**Regla a partir de ahora:** el único que escribe
`Tbl_Bodega_Producto.Cantidad` es el trigger `tr_ActualizarStock_Desde_Kardex`.
Ningún procedimiento vuelve a hacer `UPDATE` de esa columna a mano. El
trigger rechaza con error cualquier movimiento que llegue sin
`Id_Bodega_Producto`, para que un bug así no vuelva a pasar en silencio.

## Otros arreglos incluidos

- **`tr_EvitarStockNegativo` estaba muerto**: vigilaba `Tbl_Bodega`, pero el
  stock se mudó a `Tbl_Bodega_Producto` en la migración multi-bodega.
  Reemplazado por una validación dentro del trigger + un `CHECK` de tabla.
- **Bug de variable en el cursor de anulación de venta**: en T-SQL,
  `SELECT @var = columna` deja la variable con el valor de la iteración
  anterior si no encuentra filas. Se estaba escribiendo ese valor fantasma
  en el kardex. Los cursores se reemplazaron por `INSERT...SELECT`.
- **Condición de carrera de stock**: se lee con `UPDLOCK, HOLDLOCK` dentro
  de la transacción. Antes dos cajeros vendiendo la última unidad pasaban
  ambos la validación.
- **Totales recalculados en el servidor** en venta y compra, en vez de
  guardar el número que mandara el cliente.

## Convención para migraciones nuevas

`NNN_descripcion_corta.sql`, número correlativo, nunca editar una ya
aplicada en producción — se crea la siguiente.
