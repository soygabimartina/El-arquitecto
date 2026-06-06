# Guía del Proyecto: Northwind DWA (Data Warehouse Analítico)

## ¿Qué se construyó?

Se armó una **base de datos analítica** (Data Warehouse) a partir de los datos de Northwind,
usando **SQLite** como motor. El proyecto transforma datos crudos en CSV hacia un modelo
dimensional limpio y enriquecido, listo para conectar con **Power BI**.

El pipeline tiene **4 etapas** y **26 scripts SQL** que se ejecutan en orden.

---

## Estructura de carpetas

```
northwind-dwa/
│
├── db/                          ← acá va el archivo northwind_dwa.db (lo creás vos en SQLiteStudio)
│
├── data/
│   ├── ingesta1/                ← los CSV originales de Northwind
│   │   ├── categories.csv
│   │   ├── customers.csv
│   │   ├── employees.csv
│   │   ├── suppliers.csv
│   │   ├── products.csv
│   │   ├── shippers.csv
│   │   ├── orders.csv
│   │   ├── order_details.csv
│   │   ├── territories.csv
│   │   ├── regions.csv
│   │   └── employee_territories.csv
│   │
│   └── ingesta2/                ← actualizaciones y enriquecimiento
│       ├── orders_update.csv    ← órdenes nuevas o modificadas
│       ├── world-data-2023.csv  ← datos socioeconómicos por país
│       └── customer_score.csv   ← score de lealtad por cliente
│
├── loaders/
│   └── load_csv.py              ← script Python para cargar los CSV a SQLite
│
└── scripts/
    ├── 00_init/                 ← inicialización de la base
    ├── 01_adquisicion/          ← carga y validación de datos crudos
    ├── 02_ingenieria/           ← construcción del modelo dimensional
    ├── 03_actualizacion/        ← segunda ingesta y enriquecimiento
    └── 04_publicacion/          ← productos de datos finales para Power BI
```

---

## Las capas de la base de datos

Todas las tablas viven en **un solo archivo `.db`** pero se diferencian por prefijo:

| Prefijo | Nombre       | Para qué sirve                                      |
|---------|--------------|-----------------------------------------------------|
| `TXT_`  | Raw / Crudo  | Datos cargados tal cual del CSV, todo texto         |
| `TMP_`  | Tipado       | Mismos datos pero con tipos correctos (INT, REAL)   |
| `DWA_`  | Dimensional  | Modelo estrella: dimensiones + tabla de hechos      |
| `DWM_`  | Memoria      | Historial de cambios (quién cambió qué y cuándo)   |
| `DQM_`  | Calidad      | Logs, alertas y controles de calidad del proceso    |
| `MET_`  | Metadatos    | Documentación de tablas, campos y procesos ETL      |
| `DP0x_` | Productos    | Tablas finales para Power BI (ventas, clientes)     |

---

## Cómo ejecutar el proyecto (paso a paso)

### PASO 1 — Crear la base de datos vacía

1. Abrí **SQLiteStudio**
2. Menú: Database → Add a database → Create new database
3. Guardala como `northwind-dwa/db/northwind_dwa.db`

---

### PASO 2 — Inicialización (ejecutar en SQLiteStudio)

Abrí cada script y ejecutalo con F9 o el botón "Run":

```
scripts/00_init/S00_create_infrastructure.sql   ← crea tablas DQM (logs, control calidad)
scripts/00_init/S01_populate_inventory.sql       ← registra todos los scripts en el inventario
```

---

### PASO 3 — Cargar los CSV de Ingesta 1 (ejecutar en Terminal)

Primero corrés el loader Python para cargar los CSV en las tablas `TXT_`:

```bash
cd northwind-dwa/loaders
python load_csv.py --ingesta 1 --db ../db/northwind_dwa.db
```

> Si no tenés Python instalado: `pip install` no requiere librerías extra, solo Python 3.

---

### PASO 4 — Adquisición: crear tablas y validar (SQLiteStudio)

```
scripts/01_adquisicion/S10_create_txt_tables.sql    ← crea tablas TXT_ vacías
scripts/01_adquisicion/S11_create_tmp_tables.sql    ← crea tablas TMP_ con tipos y PK
scripts/01_adquisicion/S12_validate_txt_format.sql  ← valida tipos y rangos en TXT_
scripts/01_adquisicion/S13_validate_pk.sql          ← valida que no haya duplicados de PK
scripts/01_adquisicion/S14_profiling.sql            ← cuenta nulos, distintos, min/max
scripts/01_adquisicion/S15_txt_to_tmp.sql           ← copia TXT_ → TMP_ con CAST y filtros
scripts/01_adquisicion/S16_validate_referential.sql ← valida que las FK no estén huérfanas
```

---

### PASO 5 — Ingeniería: construir el modelo dimensional (SQLiteStudio)

```
scripts/02_ingenieria/S20_create_metadata.sql    ← crea tablas MET_ de documentación
scripts/02_ingenieria/S21_populate_metadata.sql  ← documenta todas las entidades
scripts/02_ingenieria/S22_create_dwa_model.sql   ← crea el modelo estrella (DIM_ + FACT_)
scripts/02_ingenieria/S23_create_dwm_memory.sql  ← crea tablas de historial de cambios
scripts/02_ingenieria/S24_create_enrichment.sql  ← crea vistas analíticas para Power BI
scripts/02_ingenieria/S25_create_dqm_full.sql    ← extiende el sistema de calidad
scripts/02_ingenieria/S26_initial_load.sql       ← carga inicial TMP_ → DWA_ (dimensiones + fact)
```

---

### PASO 6 — Cargar los CSV de Ingesta 2 (Terminal)

```bash
cd northwind-dwa/loaders
python load_csv.py --ingesta 2 --db ../db/northwind_dwa.db --append
```

> El flag `--append` es importante: no borra las órdenes existentes, agrega las nuevas.

---

### PASO 7 — Actualización: aplicar Ingesta 2 (SQLiteStudio)

```
scripts/03_actualizacion/S30_load_ingesta2_txt.sql    ← registra la ingesta en el log
scripts/03_actualizacion/S31_validate_ingesta2.sql    ← valida calidad de los nuevos datos
scripts/03_actualizacion/S32_update_dwa.sql           ← actualiza dimensiones y fact con novedades
scripts/03_actualizacion/S33_update_memory.sql        ← guarda historial de cambios (SCD tipo 2)
scripts/03_actualizacion/S34_update_enrichment.sql    ← recalcula campos derivados
scripts/03_actualizacion/S35_add_world_data.sql       ← incorpora datos por país (PIB, capital)
scripts/03_actualizacion/S36_add_customer_score.sql   ← incorpora score y segmento por cliente
```

---

### PASO 8 — Publicación: crear los productos de datos (SQLiteStudio)

```
scripts/04_publicacion/S40_create_dp_ventas.sql     ← crea DP01_VENTAS (tabla lista para Power BI)
scripts/04_publicacion/S41_create_dp_clientes.sql   ← crea DP02_CLIENTES (tabla lista para Power BI)
scripts/04_publicacion/S42_register_products.sql    ← registra todo y genera resumen final
```

---

## El modelo estrella (qué tablas conectan con qué)

```
                    DWA_DIM_TIEMPO
                         │
DWA_DIM_EMPLEADO ────────┤
                         │
DWA_DIM_PRODUCTO ────────┼──── DWA_FACT_VENTAS (tabla central)
                         │
DWA_DIM_CLIENTE  ────────┤
                         │
DWA_DIM_SHIPPER  ────────┘

DWA_DIM_ORDEN      ← dimensión degenerada (info adicional de la orden)
DWA_DIM_GEOGRAFIA  ← enriquecimiento geográfico de clientes
```

**Grain de la FACT:** una fila por cada línea de orden (order_id × product_id)

---

## Las dos tablas finales para Power BI

### DP01_VENTAS
Ventas agregadas por período, producto y cliente.

Columnas principales:
- `anio`, `trimestre`, `mes`, `nombre_mes`
- `product_name`, `category_name`
- `company_name`, `cliente_pais`, `segmento`
- `empleado_nombre`
- `unidades_vendidas`, `monto_bruto_total`, `monto_neto_total`, `descuento_prom_pct`

### DP02_CLIENTES
Perfil completo del cliente con métricas de compra.

Columnas principales:
- `customer_id`, `company_name`, `cliente_pais`
- `score`, `segmento` (ALTO / MEDIO / BAJO / SIN_DATOS)
- `pais_pib`, `pais_capital`, `pais_poblacion`
- `total_pedidos`, `ingreso_neto_total`, `ticket_promedio_neto`
- `primera_compra`, `ultima_compra`

---

## El enriquecimiento (qué agrega Ingesta 2)

| Dato agregado         | Fuente CSV             | Columnas en DWA                   |
|-----------------------|------------------------|-----------------------------------|
| Score de lealtad      | `customer_score.csv`   | `DIM_CLIENTE.score`, `.segmento`  |
| PIB del país          | `world-data-2023.csv`  | `DIM_CLIENTE.pais_pib`            |
| Capital del país      | `world-data-2023.csv`  | `DIM_GEOGRAFIA.capital`           |
| Población del país    | `world-data-2023.csv`  | `DIM_GEOGRAFIA.poblacion`         |

---

## Cómo monitorear la calidad

Después de correr los scripts, podés consultar:

```sql
-- Ver todos los controles de calidad
SELECT tabla, campo, tipo_control, pct_calidad, decision
FROM DQM_CONTROL_CAMPO
ORDER BY pct_calidad ASC;

-- Ver alertas activas
SELECT nivel, tabla, mensaje FROM DQM_ALERTA ORDER BY nivel;

-- Ver el log de ejecución de scripts
SELECT script_id, resultado, mensaje FROM DQM_LOG_EJECUCION ORDER BY log_id;

-- Ver el resumen global de calidad
SELECT * FROM VW_DQM_RESUMEN;
```

---

## Historial de cambios (SCD Tipo 2)

Si un cliente cambió de ciudad o un producto cambió de precio entre Ingesta 1 e Ingesta 2,
el cambio queda registrado en:

```sql
-- Ver cambios en clientes
SELECT customer_id, campo_modificado, valor_anterior, valor_nuevo, fecha_desde
FROM DWM_CLIENTE_HIST
ORDER BY fecha_desde DESC;

-- Ver cambios en precios de productos
SELECT product_id, campo_modificado, valor_anterior, valor_nuevo
FROM DWM_PRODUCTO_HIST;
```

---

## Vistas listas para Power BI

| Vista                       | Para qué usarla                                    |
|-----------------------------|----------------------------------------------------|
| `VW_FACT_VENTAS_COMPLETA`   | Una fila por venta con todos los atributos unidos  |
| `VW_KPI_CATEGORIA_MES`      | KPIs de ventas por categoría y mes                 |
| `VW_ENRIQUECIMIENTO_STATUS` | Qué % de filas tienen datos de enriquecimiento     |
| `VW_DQM_RESUMEN`            | Calidad por tipo de control e ingesta              |

---

## Resumen de scripts por etapa

| Etapa | Script | Qué hace |
|-------|--------|----------|
| 00 | S00 | Crea infraestructura DQM (logs y tablas de control) |
| 00 | S01 | Registra los 26 scripts en el inventario |
| 01 | S10 | Crea 11 tablas TXT_ (todo texto) |
| 01 | S11 | Crea 8 tablas TMP_ (con tipos y PK) |
| 01 | S12 | Valida formato campo a campo en TXT_ |
| 01 | S13 | Valida unicidad de PK |
| 01 | S14 | Perfilado estadístico (nulos, min, max) |
| 01 | S15 | Mueve datos TXT_ → TMP_ con CAST y filtros |
| 01 | S16 | Valida integridad referencial en TMP_ |
| 02 | S20 | Crea tablas de metadatos (MET_) |
| 02 | S21 | Documenta entidades, atributos y procesos ETL |
| 02 | S22 | Crea el modelo estrella DWA_ |
| 02 | S23 | Crea tablas de historial SCD DWM_ |
| 02 | S24 | Crea vistas analíticas para Power BI |
| 02 | S25 | Extiende DQM con alertas y resúmenes |
| 02 | S26 | Carga inicial TMP_ → dimensiones + fact |
| 03 | S30 | Registra Ingesta 2 en el log |
| 03 | S31 | Valida calidad de los datos de Ingesta 2 |
| 03 | S32 | Actualiza DWA con novedades de Ingesta 2 |
| 03 | S33 | Registra historial de cambios en DWM_ |
| 03 | S34 | Recalcula campos derivados (monto, días) |
| 03 | S35 | Incorpora world-data-2023 al DWA |
| 03 | S36 | Incorpora customer_score al DWA |
| 04 | S40 | Crea DP01_VENTAS |
| 04 | S41 | Crea DP02_CLIENTES |
| 04 | S42 | Registra DPs y genera resumen final |
