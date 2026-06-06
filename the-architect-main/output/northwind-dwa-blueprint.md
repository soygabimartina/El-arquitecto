# Blueprint — Northwind DWA (TP Flujo de datos)
**Materia:** Introducción a Data Warehousing — Ingeniería de Datos  
**Proyecto:** TPG01 — Flujo de datos en un DWA  
**Stack:** SQLite + SQLiteStudio + Python (carga CSV) + Power BI

---

## 1. Visión general

Implementar el flujo end-to-end de un Data Warehouse Analítico (DWA) sobre la base Northwind:
adquisición desde CSV → validación → modelo dimensional → actualización → producto de datos → tablero.

**Objetivos de negocio:**
- Analizar ventas por período, producto, cliente, empleado y geografía
- Detectar tendencias de compra y clientes de mayor valor
- Monitorear calidad de datos a lo largo de todo el flujo

---

## 2. Tech Stack

| Componente | Herramienta | Justificación |
|---|---|---|
| Base de datos | SQLite 3 | Requerido por la cátedra. Sin servidor, portable |
| IDE de base | SQLiteStudio | GUI recomendada por la cátedra |
| Carga de CSV | Python 3 + sqlite3 | `IMPORT` de SQLite no soporta bien headers; Python es más robusto |
| Tableros | Power BI Desktop | Recomendado por la cátedra. Conecta directo a .db |
| Control de scripts | SQL (tabla inventario) | Requerido por la cátedra |

---

## 3. Estructura de directorios

```
northwind-dwa/
├── data/
│   ├── ingesta1/                  # CSVs de la primera ingesta (Northwind transaccional)
│   │   ├── categories.csv
│   │   ├── customers.csv
│   │   ├── employees.csv
│   │   ├── employee_territories.csv
│   │   ├── order_details.csv
│   │   ├── orders.csv
│   │   ├── products.csv
│   │   ├── regions.csv
│   │   ├── shippers.csv
│   │   ├── suppliers.csv
│   │   └── territories.csv
│   └── ingesta2/                  # CSVs de actualización + tablas externas
│       ├── orders_update.csv      # subconjunto de orders
│       ├── world-data-2023.csv    # tabla externa de países
│       └── customer_score.csv     # tabla externa de scoring de clientes
│
├── scripts/
│   ├── 00_init/
│   │   ├── S00_create_infrastructure.sql   # LOG, Inventario, DQM base
│   │   └── S01_populate_inventory.sql      # registrar todos los scripts
│   │
│   ├── 01_adquisicion/
│   │   ├── S10_create_txt_tables.sql       # tablas TXT_ (todo TEXT)
│   │   ├── S11_create_tmp_tables.sql       # tablas TMP_ (tipos + PK)
│   │   ├── S12_validate_txt_format.sql     # control de formato campo a campo
│   │   ├── S13_validate_pk.sql             # control de unicidad de PK
│   │   ├── S14_profiling.sql               # perfilado: nulos, distintos, min/max
│   │   ├── S15_txt_to_tmp.sql              # copia TXT → TMP si validación OK
│   │   └── S16_validate_referential.sql    # integridad referencial en TMP
│   │
│   ├── 02_ingenieria/
│   │   ├── S20_create_metadata.sql         # tablas MET_
│   │   ├── S21_populate_metadata.sql       # describir todas las entidades
│   │   ├── S22_create_dwa_model.sql        # tablas DWA_ (estrella)
│   │   ├── S23_create_dwm_memory.sql       # tablas DWM_ (SCD tipo 2)
│   │   ├── S24_create_enrichment.sql       # campos derivados en DWA
│   │   ├── S25_create_dqm_full.sql         # DQM completo
│   │   └── S26_initial_load.sql            # carga inicial TMP → DWA
│   │
│   ├── 03_actualizacion/
│   │   ├── S30_load_ingesta2_txt.sql       # cargar Ingesta2 en TXT_
│   │   ├── S31_validate_ingesta2.sql       # repetir controles
│   │   ├── S32_update_dwa.sql              # altas/bajas/modificaciones en DWA
│   │   ├── S33_update_memory.sql           # persistir historia en DWM
│   │   ├── S34_update_enrichment.sql       # recalcular datos derivados
│   │   ├── S35_add_world_data.sql          # vincular world-data-2023
│   │   └── S36_add_customer_score.sql      # vincular customer_score
│   │
│   └── 04_publicacion/
│       ├── S40_create_dp_ventas.sql        # Producto de Datos: ventas
│       ├── S41_create_dp_clientes.sql      # Producto de Datos: clientes
│       └── S42_register_products.sql       # huella en DQM y Metadata
│
├── loaders/
│   └── load_csv.py                         # script Python para importar CSV a TXT_
│
├── db/
│   └── northwind_dwa.db                    # base SQLite (única para todas las capas)
│
├── dashboard/
│   └── Tablero_Ventas.pbix                 # Power BI: producto de datos
│   └── Tablero_DQM.pbix                    # Power BI: navegación del DQM
│
└── docs/
    ├── DER_transaccional.png
    ├── DER_dimensional.png
    └── informe_TP.pdf
```

---

## 4. Modelo de capas (prefijos de tablas)

| Prefijo | Capa | Descripción |
|---|---|---|
| `TXT_` | Staging raw | Todo en TEXT/VARCHAR, sin tipos ni PK |
| `TMP_` | Staging tipado | Tipos de datos correctos + PK definidas |
| `ING_` | Ingesta | Vista previa antes de pasar al DWA (opcional) |
| `DWA_` | Data Warehouse | Modelo dimensional (estrella) |
| `DWM_` | Memoria | SCD Tipo 2 — historia de campos modificados |
| `DQM_` | Data Quality Mart | Logs, perfilados, controles de calidad |
| `MET_` | Metadata | Catálogo de entidades, atributos y procesos |
| `DP01_` | Producto de Datos | Ventas por período/producto/cliente |
| `DP02_` | Producto de Datos | Clientes con score y datos país |

---

## 5. Modelo dimensional (DWA)

### Tabla de hechos principal
```sql
DWA_FACT_VENTAS (
  venta_id        INTEGER PRIMARY KEY,
  order_id        INTEGER,  -- FK → DWA_DIM_ORDEN
  product_id      INTEGER,  -- FK → DWA_DIM_PRODUCTO
  customer_id     TEXT,     -- FK → DWA_DIM_CLIENTE
  employee_id     INTEGER,  -- FK → DWA_DIM_EMPLEADO
  shipper_id      INTEGER,  -- FK → DWA_DIM_SHIPPER
  fecha_id        INTEGER,  -- FK → DWA_DIM_TIEMPO
  unit_price      REAL,
  quantity        INTEGER,
  discount        REAL,
  monto_bruto     REAL,     -- ENRICHMENT: unit_price * quantity
  monto_neto      REAL,     -- ENRICHMENT: monto_bruto * (1 - discount)
  fecha_carga     TEXT,
  ingesta_id      INTEGER
)
```

### Dimensiones
```sql
DWA_DIM_TIEMPO      (fecha_id, fecha, anio, trimestre, mes, semana, dia, nombre_mes)
DWA_DIM_CLIENTE     (customer_id, company_name, city, country, region, score)  -- enriquecida con customer_score
DWA_DIM_PRODUCTO    (product_id, product_name, category_id, category_name, supplier_id, unit_price, discontinued)
DWA_DIM_EMPLEADO    (employee_id, full_name, title, city, country, reports_to)
DWA_DIM_SHIPPER     (shipper_id, company_name)
DWA_DIM_GEOGRAFIA   (geo_id, country, state_name, state_abbr, region -- enriquecida con world-data-2023)
```

### Capa de Memoria (SCD Tipo 2)
```sql
DWM_CLIENTE_HIST (
  hist_id         INTEGER PRIMARY KEY,
  customer_id     TEXT,
  campo_modificado TEXT,
  valor_anterior  TEXT,
  valor_nuevo     TEXT,
  fecha_desde     TEXT,
  fecha_hasta     TEXT,
  ingesta_id      INTEGER
)

DWM_PRODUCTO_HIST (
  hist_id, product_id, campo_modificado,
  valor_anterior, valor_nuevo, fecha_desde, fecha_hasta, ingesta_id
)
```

### Capa de Enriquecimiento (calculado en DWA_FACT_VENTAS)
- `monto_bruto = unit_price * quantity`
- `monto_neto = monto_bruto * (1 - discount)`
- `dias_entrega` (en DWA_DIM_ORDEN) = `shipped_date - order_date`
- `score_cliente` (de customer_score)
- `region_mundo` (de world-data-2023)

---

## 6. DQM — Data Quality Mart

```sql
-- Registro de ejecución de scripts
DQM_LOG_EJECUCION (
  log_id          INTEGER PRIMARY KEY,
  script_id       TEXT,
  script_nombre   TEXT,
  fecha_inicio    TEXT,
  fecha_fin       TEXT,
  resultado       TEXT,   -- 'OK' | 'ERROR' | 'WARNING'
  mensaje         TEXT,
  registros_proc  INTEGER
)

-- Inventario de scripts
DQM_INVENTARIO_SCRIPTS (
  script_id       TEXT PRIMARY KEY,
  script_nombre   TEXT,
  etapa           TEXT,
  descripcion     TEXT,
  fecha_creacion  TEXT,
  autor           TEXT
)

-- Controles de calidad por campo
DQM_CONTROL_CAMPO (
  control_id      INTEGER PRIMARY KEY,
  ingesta_id      INTEGER,
  tabla           TEXT,
  campo           TEXT,
  tipo_control    TEXT,   -- 'NULOS' | 'TIPO' | 'RANGO' | 'UNICIDAD' | 'RI'
  total_registros INTEGER,
  registros_ok    INTEGER,
  registros_error INTEGER,
  pct_calidad     REAL,
  umbral_minimo   REAL,   -- % mínimo para aceptar
  decision        TEXT,   -- 'ACEPTADO' | 'RECHAZADO' | 'PARCIAL'
  fecha           TEXT
)

-- Perfilado de tablas (totales de control)
DQM_PERFILADO (
  perfil_id       INTEGER PRIMARY KEY,
  ingesta_id      INTEGER,
  tabla           TEXT,
  total_filas     INTEGER,
  total_columnas  INTEGER,
  nulos_total     INTEGER,
  duplicados_pk   INTEGER,
  fecha           TEXT
)

-- Huella de transformaciones
DQM_TRANSFORMACION (
  transf_id       INTEGER PRIMARY KEY,
  ingesta_id      INTEGER,
  origen          TEXT,
  destino         TEXT,
  tipo            TEXT,   -- 'COPIA' | 'INSERT' | 'UPDATE' | 'DELETE'
  registros_afect INTEGER,
  fecha           TEXT
)
```

---

## 7. Metadata

```sql
MET_ENTIDAD (
  entidad_id      INTEGER PRIMARY KEY,
  nombre          TEXT,
  capa            TEXT,   -- 'TXT' | 'TMP' | 'DWA' | 'DQM' | 'MET' | 'DP'
  descripcion     TEXT,
  fecha_creacion  TEXT,
  activo          INTEGER
)

MET_ATRIBUTO (
  atributo_id     INTEGER PRIMARY KEY,
  entidad_id      INTEGER,
  nombre_campo    TEXT,
  tipo_dato       TEXT,
  descripcion     TEXT,
  es_pk           INTEGER,
  es_fk           INTEGER,
  tabla_ref       TEXT,
  campo_ref       TEXT
)

MET_PROCESO (
  proceso_id      INTEGER PRIMARY KEY,
  script_id       TEXT,
  descripcion     TEXT,
  entidades_input TEXT,
  entidades_output TEXT,
  fecha_registro  TEXT
)
```

---

## 8. Orden de construcción (BUILD ORDER)

### Fase 0 — Setup
1. Crear la base `northwind_dwa.db` en SQLiteStudio
2. Ejecutar `S00_create_infrastructure.sql` → crea DQM_LOG, DQM_INVENTARIO, DQM_CONTROL_CAMPO, DQM_PERFILADO, DQM_TRANSFORMACION
3. Ejecutar `S01_populate_inventory.sql` → registra todos los scripts en DQM_INVENTARIO_SCRIPTS

### Fase 1 — Adquisición (Ingesta1)
4. Ejecutar `S10_create_txt_tables.sql` → crea TXT_CUSTOMERS, TXT_ORDERS, TXT_ORDER_DETAILS, etc.
5. Ejecutar `S11_create_tmp_tables.sql` → crea TMP_CUSTOMERS, TMP_ORDERS, etc. con tipos y PK
6. Correr `load_csv.py ingesta1` → carga CSV a tablas TXT_
7. Ejecutar `S12_validate_txt_format.sql` → valida que cada campo sea convertible a su tipo
8. Ejecutar `S13_validate_pk.sql` → verifica unicidad antes de mover a TMP
9. Ejecutar `S14_profiling.sql` → registra perfilado en DQM_PERFILADO
10. Si validación OK → Ejecutar `S15_txt_to_tmp.sql`
11. Ejecutar `S16_validate_referential.sql` → verifica FKs en TMP

### Fase 2 — Ingeniería
12. Ejecutar `S20_create_metadata.sql` → crea tablas MET_
13. Ejecutar `S21_populate_metadata.sql` → documenta todas las entidades del DWA
14. Ejecutar `S22_create_dwa_model.sql` → crea DWA_FACT_VENTAS + todas las DIM
15. Ejecutar `S23_create_dwm_memory.sql` → crea DWM_CLIENTE_HIST, DWM_PRODUCTO_HIST
16. Ejecutar `S24_create_enrichment.sql` → agrega columnas calculadas
17. Ejecutar `S25_create_dqm_full.sql` → tablas DQM adicionales
18. Ejecutar `S26_initial_load.sql` → carga TMP → DWA (respetando orden de prevalencia: DIM antes que FACT)

### Fase 3 — Actualización (Ingesta2)
19. Correr `load_csv.py ingesta2` → carga Ingesta2 a TXT_
20. Ejecutar `S30_load_ingesta2_txt.sql` → persistir en área temporal
21. Ejecutar `S31_validate_ingesta2.sql` → mismos controles que Ingesta1
22. Ejecutar `S32_update_dwa.sql` → INSERT nuevos / UPDATE modificados / marca bajas
23. Ejecutar `S33_update_memory.sql` → registrar historia de campos modificados en DWM
24. Ejecutar `S34_update_enrichment.sql` → recalcular monto_bruto, monto_neto, dias_entrega
25. Ejecutar `S35_add_world_data.sql` → cargar world-data-2023, vincular con DIM_GEOGRAFIA/DIM_CLIENTE
26. Ejecutar `S36_add_customer_score.sql` → cargar customer_score, actualizar DIM_CLIENTE

### Fase 4 — Publicación
27. Ejecutar `S40_create_dp_ventas.sql` → tabla DP01_VENTAS (agregada por mes/producto/cliente)
28. Ejecutar `S41_create_dp_clientes.sql` → tabla DP02_CLIENTES (con score y datos de país)
29. Ejecutar `S42_register_products.sql` → registrar DPs en DQM y Metadata
30. Conectar Power BI a `northwind_dwa.db`
31. Crear Tablero_Ventas.pbix (visualiza DP01)
32. Crear Tablero_DQM.pbix (navega por DQM_LOG, DQM_CONTROL_CAMPO, DQM_PERFILADO)

---

## 9. Setup de entorno

### Requisitos
- SQLiteStudio 3.4+ (descarga: sqlitestudio.pl)
- Python 3.9+ con librería `sqlite3` (incluida en stdlib)
- Power BI Desktop (descarga gratuita desde Microsoft)

### Primeros pasos
```bash
# 1. Crear la base de datos
# Abrir SQLiteStudio → Database → Add a Database → northwind_dwa.db

# 2. Cargar CSV con Python
python loaders/load_csv.py --ingesta 1 --db db/northwind_dwa.db

# 3. Ejecutar scripts en orden
# Abrir cada .sql en SQLiteStudio y ejecutar (F9)
```

### Variables de entorno (load_csv.py)
```
DB_PATH=db/northwind_dwa.db
INGESTA1_PATH=data/ingesta1/
INGESTA2_PATH=data/ingesta2/
```

---

## 10. Dependencias

| Herramienta | Versión | Uso |
|---|---|---|
| SQLite | 3.x (incluido en SQLiteStudio) | Motor de base de datos |
| SQLiteStudio | 3.4+ | IDE y ejecución de scripts |
| Python | 3.9+ | Carga de CSV a TXT_ |
| Power BI Desktop | Última | Visualización |

---

## 11. Controles de calidad — definición por tabla

### Umbrales de aceptación
| Control | Umbral mínimo | Decisión si falla |
|---|---|---|
| % campos nulos en PK | 0% | RECHAZAR tabla |
| % duplicados en PK | 0% | RECHAZAR tabla |
| % tipo de dato incompatible | < 5% | WARNING; > 5% → RECHAZAR |
| % nulos en campos obligatorios | < 10% | WARNING; > 10% → PARCIAL |
| Integridad referencial (FK) | > 95% | WARNING; < 95% → RECHAZAR |

### Outliers a detectar
- `unit_price` < 0 o > 10.000
- `quantity` < 0 o > 10.000
- `discount` < 0 o > 1
- `order_date` anterior a 1990 o posterior a hoy
- `freight` < 0

---

## 12. Estrategia de actualización (SCD)

- **Clientes y Productos**: SCD Tipo 2 — al detectar un cambio, se registra en DWM_ el valor anterior con `fecha_hasta = hoy` y se inserta el nuevo con `fecha_desde = hoy`
- **Bajas**: se marca `activo = 0` en la dimensión, no se elimina físicamente
- **Nuevos registros**: INSERT directo en DWA
- **Orden de prevalencia**: DIM_TIEMPO → DIM_CLIENTE → DIM_PRODUCTO → DIM_EMPLEADO → DIM_SHIPPER → FACT_VENTAS

---

## 13. Reglas no negociables

1. Todo script debe registrar inicio/fin/resultado en DQM_LOG_EJECUCION
2. Nunca pasar datos al DWA sin superar los umbrales de calidad
3. Nunca eliminar físicamente registros del DWA (usar flag `activo`)
4. Todo cambio en DIM registrado con historia en DWM
5. Toda entidad del DWA documentada en MET_ENTIDAD y MET_ATRIBUTO
6. Los DPs (DP01_, DP02_) son de solo lectura — se regeneran desde DWA
7. Un único archivo .db para todas las capas (diferenciadas por prefijo)
8. Documentar cada script con comentarios indicando: etapa, script_id, descripción, fecha
