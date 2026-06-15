# Guía: Tableros en Power BI (DP + DQM)

Esta guía explica cómo generar los CSV que alimentan los tableros de Power BI
y cómo armar los informes pedidos en el punto 13 de la consigna:

- **13a**: tablero del producto de datos (negocio) → DP01_VENTAS, DP02_CLIENTES, DP03_PRODUCTOS
- **13b**: tablero que navega el DQM (calidad) → DQM_LOG_EJECUCION, DQM_CONTROL_CAMPO, DQM_ALERTA, DQM_RESUMEN_CALIDAD

---

## Paso 1 — Exportar las tablas a CSV

El script `loaders/export_to_csv.py` se conecta a `northwind_dwa.db` y vuelca
cada tabla a un archivo CSV dentro de la carpeta `exports/`.

```bash
cd northwind-dwa/loaders
python export_to_csv.py --db ../db/northwind_dwa.db
```

Por defecto exporta estas tablas (si alguna no existe en tu base, se omite
con un `[WARN]` y el script sigue):

| Tabla | Para qué tablero |
|---|---|
| `DP01_VENTAS` | 13a — análisis de ventas |
| `DP02_CLIENTES` | 13a — perfil/segmentación de clientes |
| `DP03_PRODUCTOS` | 13a — catálogo/performance de productos |
| `DQM_LOG_EJECUCION` | 13b — ejecución del pipeline |
| `DQM_CONTROL_CAMPO` | 13b — % de calidad por tabla/campo |
| `DQM_ALERTA` | 13b — alertas detectadas y resueltas |
| `DQM_RESUMEN_CALIDAD` | 13b — resumen de calidad por ingesta |
| `DQM_INVENTARIO_SCRIPTS` | 13b — inventario de scripts del pipeline |

Resultado: una carpeta `northwind-dwa/exports/` con un `.csv` por tabla,
por ejemplo `DP01_VENTAS.csv`, `DQM_ALERTA.csv`, etc.

Si querés exportar solo algunas tablas:

```bash
python export_to_csv.py --db ../db/northwind_dwa.db --tables DP01_VENTAS DP02_CLIENTES
```

---

## Paso 2 — Importar los CSV en Power BI

1. Abrí Power BI Desktop → **Obtener datos → Carpeta**.
2. Seleccioná la carpeta `exports/` completa. Power BI te va a mostrar
   todos los CSV juntos en una vista previa combinada.
3. En lugar de "Combinar y transformar" (que apila todo en una sola tabla),
   usá **Transformar datos** y cargá **cada CSV como tabla separada**:
   la forma más simple es repetir "Obtener datos → Texto/CSV" archivo por
   archivo y elegir "Cargar" para cada uno.
4. Revisá los tipos de columna que detecta Power BI (fechas, números,
   decimales) — especialmente en `DP01_VENTAS` (montos, fechas) y
   `DQM_CONTROL_CAMPO` (`pct_calidad` debe quedar como decimal).

---

## Paso 3 — Modelo de datos (relaciones)

### Para el tablero 13a (negocio)

- `DP01_VENTAS` es la tabla "ancha" central (grano: línea de venta).
- `DP02_CLIENTES` (grano: cliente vigente) — relación 1 a muchos con
  `DP01_VENTAS` por `customer_id`.
- `DP03_PRODUCTOS` (grano: producto vigente) — relación 1 a muchos con
  `DP01_VENTAS` por `product_id`.
- Creá una **tabla de fechas** con DAX (`CALENDAR()` o `CALENDARAUTO()`)
  y relacionala con la columna de fecha/año-mes de `DP01_VENTAS`. Esto te
  da jerarquías Año/Trimestre/Mes para los slicers.

### Para el tablero 13b (DQM)

- `DQM_CONTROL_CAMPO`, `DQM_ALERTA`, `DQM_LOG_EJECUCION`,
  `DQM_RESUMEN_CALIDAD` se relacionan entre sí por `ingesta_id`
  (y `DQM_LOG_EJECUCION` por `script_id` con `DQM_INVENTARIO_SCRIPTS`).
- No hace falta relacionarlas con las tablas de negocio (DP01/02/03):
  es un módulo de auditoría aparte. Si querés cruzarlas, podés vincular
  por `ingesta_id` o por nombre de tabla (`tabla` en `DQM_CONTROL_CAMPO`
  vs el nombre de la tabla DP), pero para la consigna no es obligatorio.

---

## Paso 4 — Páginas sugeridas

### Tablero 13a — Producto de datos

- **Página "Ventas"**: KPIs (ingreso total, cantidad de pedidos, ticket
  promedio), evolución mensual/trimestral, top productos, ventas por país.
- **Página "Clientes"**: distribución por `segmento`, top clientes por
  ingreso, relación entre `pais_pib`/`pais_poblacion` y volumen de compra.
- **Página "Productos"**: ranking por ingreso/unidades, categorías más
  rentables, productos con cambios de precio (`pct_cambio_precio` si está
  en `DP03_PRODUCTOS`).

### Tablero 13b — Navegación del DQM

- **Página "Ejecución del pipeline"**: tabla de `DQM_LOG_EJECUCION`
  (script, fecha, resultado OK/ERROR/WARNING, registros procesados).
- **Página "Calidad por campo"**: `DQM_CONTROL_CAMPO` con `pct_calidad`
  por tabla/campo, semáforo según `decision` (ACEPTADO/RECHAZADO/PARCIAL).
- **Página "Alertas"**: `DQM_ALERTA` filtrable por `tipo`/`nivel`, mostrando
  detección y (si tu modelo lo registra) resolución.

---

## Paso 5 — Medidas DAX útiles (de referencia)

```dax
-- 13a
Ingreso Neto Total = SUM(DP01_VENTAS[monto_neto_total])
Ticket Promedio = AVERAGE(DP01_VENTAS[monto_neto_total])

-- 13b
% Calidad Promedio = AVERAGE(DQM_CONTROL_CAMPO[pct_calidad])
Controles Rechazados = CALCULATE(COUNTROWS(DQM_CONTROL_CAMPO), DQM_CONTROL_CAMPO[decision] = "RECHAZADO")
Alertas Activas = CALCULATE(COUNTROWS(DQM_ALERTA), DQM_ALERTA[nivel] = "ERROR")
```

---

## Qué tenés que descargar / hacer en tu máquina

1. Traer al repo local los archivos nuevos: `loaders/export_to_csv.py`,
   `exports/.gitkeep` y este `GUIA_TABLEROS.md` (o copiarlos manualmente
   si trabajás el proyecto solo en Windows).
2. Correr `python export_to_csv.py --db ../db/northwind_dwa.db` desde
   `loaders/` con tu base ya poblada (después de correr todo el pipeline).
3. Verificar que `exports/` tenga los CSV esperados (DP01, DP02, DP03,
   DQM_*).
4. Abrir Power BI Desktop y seguir los pasos 2 a 5 de esta guía para armar
   los dos tableros.
