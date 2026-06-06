-- =============================================================
-- Script ID : S21
-- Etapa     : 02 - Ingeniería
-- Descripción: Puebla las tablas MET_ con la documentación
--              de todas las entidades del DWA.
-- Fecha      : 2026-06-06
-- =============================================================

INSERT INTO DQM_LOG_EJECUCION (script_id, script_nombre, fecha_inicio, resultado)
VALUES ('S21', 'S21_populate_metadata.sql', datetime('now'), 'RUNNING');

-- ── Entidades: capa TXT (raw) ─────────────────────────────────
INSERT OR REPLACE INTO MET_ENTIDAD (nombre, capa, tipo, descripcion, fuente, script_creacion, fecha_creacion) VALUES
('TXT_CATEGORIES',          'TXT', 'TABLA', 'Categorías de productos (todo TEXT)',               'categories.csv',           'S10', datetime('now')),
('TXT_CUSTOMERS',           'TXT', 'TABLA', 'Clientes (todo TEXT)',                              'customers.csv',            'S10', datetime('now')),
('TXT_EMPLOYEES',           'TXT', 'TABLA', 'Empleados (todo TEXT)',                             'employees.csv',            'S10', datetime('now')),
('TXT_SUPPLIERS',           'TXT', 'TABLA', 'Proveedores (todo TEXT)',                           'suppliers.csv',            'S10', datetime('now')),
('TXT_PRODUCTS',            'TXT', 'TABLA', 'Productos (todo TEXT)',                             'products.csv',             'S10', datetime('now')),
('TXT_SHIPPERS',            'TXT', 'TABLA', 'Transportistas (todo TEXT)',                        'shippers.csv',             'S10', datetime('now')),
('TXT_ORDERS',              'TXT', 'TABLA', 'Órdenes de venta (todo TEXT)',                      'orders.csv / orders_update.csv', 'S10', datetime('now')),
('TXT_ORDER_DETAILS',       'TXT', 'TABLA', 'Líneas de orden (todo TEXT)',                       'order_details.csv',        'S10', datetime('now')),
('TXT_TERRITORIES',         'TXT', 'TABLA', 'Territorios de ventas (todo TEXT)',                 'territories.csv',          'S10', datetime('now')),
('TXT_REGIONS',             'TXT', 'TABLA', 'Regiones (todo TEXT)',                              'regions.csv',              'S10', datetime('now')),
('TXT_EMPLOYEE_TERRITORIES','TXT', 'TABLA', 'Relación empleado-territorio (todo TEXT)',          'employee_territories.csv', 'S10', datetime('now')),
('TXT_WORLD_DATA',          'TXT', 'TABLA', 'Datos socioeconómicos por país (todo TEXT)',        'world-data-2023.csv',      'S10', datetime('now')),
('TXT_CUSTOMER_SCORE',      'TXT', 'TABLA', 'Score de lealtad por cliente (todo TEXT)',          'customer_score.csv',       'S10', datetime('now'));

-- ── Entidades: capa TMP (tipada) ─────────────────────────────
INSERT OR REPLACE INTO MET_ENTIDAD (nombre, capa, tipo, descripcion, fuente, script_creacion, fecha_creacion) VALUES
('TMP_CATEGORIES',          'TMP', 'TABLA', 'Categorías con tipos correctos y PK validada',     'TXT_CATEGORIES',    'S11', datetime('now')),
('TMP_CUSTOMERS',           'TMP', 'TABLA', 'Clientes con tipos correctos y PK validada',       'TXT_CUSTOMERS',     'S11', datetime('now')),
('TMP_EMPLOYEES',           'TMP', 'TABLA', 'Empleados con tipos correctos y PK validada',      'TXT_EMPLOYEES',     'S11', datetime('now')),
('TMP_SUPPLIERS',           'TMP', 'TABLA', 'Proveedores con tipos correctos y PK validada',    'TXT_SUPPLIERS',     'S11', datetime('now')),
('TMP_PRODUCTS',            'TMP', 'TABLA', 'Productos con tipos correctos y PK validada',      'TXT_PRODUCTS',      'S11', datetime('now')),
('TMP_SHIPPERS',            'TMP', 'TABLA', 'Transportistas con tipos correctos',               'TXT_SHIPPERS',      'S11', datetime('now')),
('TMP_ORDERS',              'TMP', 'TABLA', 'Órdenes con tipos correctos y PK validada',        'TXT_ORDERS',        'S11', datetime('now')),
('TMP_ORDER_DETAILS',       'TMP', 'TABLA', 'Líneas de orden con tipos y PK compuesta validada','TXT_ORDER_DETAILS', 'S11', datetime('now'));

-- ── Entidades: capa DWA (dimensional) ────────────────────────
INSERT OR REPLACE INTO MET_ENTIDAD (nombre, capa, tipo, descripcion, fuente, script_creacion, fecha_creacion) VALUES
('DWA_DIM_TIEMPO',    'DWA', 'TABLA', 'Dimensión temporal (fecha_id = YYYYMMDD)',               'TMP_ORDERS',                     'S22', datetime('now')),
('DWA_DIM_CLIENTE',   'DWA', 'TABLA', 'Dimensión cliente enriquecida con score y world-data',   'TMP_CUSTOMERS + TXT_CUSTOMER_SCORE + TXT_WORLD_DATA', 'S22', datetime('now')),
('DWA_DIM_PRODUCTO',  'DWA', 'TABLA', 'Dimensión producto desnormalizada (con cat. y prov.)',   'TMP_PRODUCTS + TMP_CATEGORIES + TMP_SUPPLIERS', 'S22', datetime('now')),
('DWA_DIM_EMPLEADO',  'DWA', 'TABLA', 'Dimensión empleado',                                    'TMP_EMPLOYEES',                  'S22', datetime('now')),
('DWA_DIM_SHIPPER',   'DWA', 'TABLA', 'Dimensión transportista',                               'TMP_SHIPPERS',                   'S22', datetime('now')),
('DWA_DIM_GEOGRAFIA', 'DWA', 'TABLA', 'Dimensión geográfica enriquecida con world-data',        'TMP_CUSTOMERS + TXT_WORLD_DATA', 'S22', datetime('now')),
('DWA_DIM_ORDEN',     'DWA', 'TABLA', 'Dimensión degenerada de orden (días entrega y demora)',  'TMP_ORDERS',                     'S22', datetime('now')),
('DWA_FACT_VENTAS',   'DWA', 'TABLA', 'Tabla de hechos de ventas (grain: orden × producto)',    'TMP_ORDER_DETAILS + TMP_ORDERS', 'S22', datetime('now'));

-- ── Entidades: capa DWM (memoria / SCD) ──────────────────────
INSERT OR REPLACE INTO MET_ENTIDAD (nombre, capa, tipo, descripcion, fuente, script_creacion, fecha_creacion) VALUES
('DWM_CLIENTE_HIST',  'DWM', 'TABLA', 'Historia SCD tipo 2 de cambios en DIM_CLIENTE',  'DWA_DIM_CLIENTE',  'S23', datetime('now')),
('DWM_PRODUCTO_HIST', 'DWM', 'TABLA', 'Historia SCD tipo 2 de cambios en DIM_PRODUCTO', 'DWA_DIM_PRODUCTO', 'S23', datetime('now'));

-- ── Entidades: Productos de Datos ────────────────────────────
INSERT OR REPLACE INTO MET_ENTIDAD (nombre, capa, tipo, descripcion, fuente, script_creacion, fecha_creacion) VALUES
('DP01_VENTAS',    'DP', 'MART', 'Ventas mensuales por producto, cliente y empleado', 'DWA_FACT_VENTAS + DWA_DIM_*', 'S40', datetime('now')),
('DP02_CLIENTES',  'DP', 'MART', 'Perfil cliente con métricas de compra y enriquecimiento', 'DWA_DIM_CLIENTE + DWA_FACT_VENTAS', 'S41', datetime('now'));

-- ── Atributos clave: FACT_VENTAS ─────────────────────────────
INSERT OR REPLACE INTO MET_ATRIBUTO
    (entidad_nombre, atributo_nombre, tipo_dato, es_pk, es_fk, nullable, tabla_referenciada, descripcion, regla_negocio) VALUES
('DWA_FACT_VENTAS', 'venta_id',   'INTEGER', 1, 0, 0, NULL,                'PK surrogate autoincremental',          NULL),
('DWA_FACT_VENTAS', 'order_id',   'INTEGER', 0, 1, 0, 'DWA_DIM_ORDEN',    'FK orden',                              NULL),
('DWA_FACT_VENTAS', 'product_id', 'INTEGER', 0, 1, 0, 'DWA_DIM_PRODUCTO', 'FK producto',                           NULL),
('DWA_FACT_VENTAS', 'customer_id','TEXT',    0, 1, 0, 'DWA_DIM_CLIENTE',  'FK cliente',                            NULL),
('DWA_FACT_VENTAS', 'employee_id','INTEGER', 0, 1, 1, 'DWA_DIM_EMPLEADO', 'FK empleado (nullable)',                 NULL),
('DWA_FACT_VENTAS', 'shipper_id', 'INTEGER', 0, 1, 1, 'DWA_DIM_SHIPPER',  'FK transportista (nullable)',            NULL),
('DWA_FACT_VENTAS', 'fecha_id',   'INTEGER', 0, 1, 0, 'DWA_DIM_TIEMPO',   'FK fecha (formato YYYYMMDD)',            NULL),
('DWA_FACT_VENTAS', 'unit_price', 'REAL',    0, 0, 0, NULL,               'Precio unitario al momento de la venta', 'unit_price >= 0'),
('DWA_FACT_VENTAS', 'quantity',   'INTEGER', 0, 0, 0, NULL,               'Cantidad vendida',                       'quantity > 0'),
('DWA_FACT_VENTAS', 'discount',   'REAL',    0, 0, 0, NULL,               'Descuento aplicado',                     'discount BETWEEN 0 AND 1'),
('DWA_FACT_VENTAS', 'monto_bruto','REAL',    0, 0, 1, NULL,               'unit_price × quantity',                  'DERIVED'),
('DWA_FACT_VENTAS', 'monto_neto', 'REAL',    0, 0, 1, NULL,               'monto_bruto × (1 - discount)',           'DERIVED'),
('DWA_FACT_VENTAS', 'freight',    'REAL',    0, 0, 1, NULL,               'Flete prorrateado por línea',            NULL),
('DWA_FACT_VENTAS', 'ingesta_id', 'INTEGER', 0, 0, 0, NULL,               'Número de ingesta que cargó la fila',    NULL);

-- ── Atributos clave: DIM_CLIENTE ──────────────────────────────
INSERT OR REPLACE INTO MET_ATRIBUTO
    (entidad_nombre, atributo_nombre, tipo_dato, es_pk, es_fk, nullable, tabla_referenciada, descripcion, regla_negocio) VALUES
('DWA_DIM_CLIENTE', 'customer_id',       'TEXT',    1, 0, 0, NULL, 'PK natural del cliente',           NULL),
('DWA_DIM_CLIENTE', 'company_name',      'TEXT',    0, 0, 0, NULL, 'Nombre de la empresa',             NULL),
('DWA_DIM_CLIENTE', 'score',             'REAL',    0, 0, 1, NULL, 'Score de lealtad (Ingesta2)',       'score BETWEEN 0 AND 100'),
('DWA_DIM_CLIENTE', 'segmento',          'TEXT',    0, 0, 1, NULL, 'Segmento calculado por score',     'ALTO(>=70) | MEDIO(40-70) | BAJO(<40)'),
('DWA_DIM_CLIENTE', 'pais_region_mundo', 'TEXT',    0, 0, 1, NULL, 'Región geográfica del país',       'Enriquecimiento world-data'),
('DWA_DIM_CLIENTE', 'pais_pib',          'REAL',    0, 0, 1, NULL, 'PIB del país del cliente (USD)',   'Enriquecimiento world-data');

-- ── Procesos ETL ──────────────────────────────────────────────
INSERT OR REPLACE INTO MET_PROCESO (nombre, etapa, script_origen, descripcion, frecuencia) VALUES
('Carga TXT Ingesta1',         '01-Adquisicion',  'S10+load_csv.py', 'Carga CSVs de Ingesta1 en tablas TXT_',             'UNICA'),
('Validación formato TXT',     '01-Adquisicion',  'S12',             'Valida tipos y rangos campo a campo en TXT_',        'POR_INGESTA'),
('Validación PK TXT',          '01-Adquisicion',  'S13',             'Verifica unicidad de claves primarias en TXT_',      'POR_INGESTA'),
('Perfilado TXT',              '01-Adquisicion',  'S14',             'Perfilado estadístico: nulos, distintos, min/max',   'POR_INGESTA'),
('Copia TXT → TMP',            '01-Adquisicion',  'S15',             'Mueve datos tipados de TXT a TMP con filtros',       'POR_INGESTA'),
('Validación RI TMP',          '01-Adquisicion',  'S16',             'Verifica integridad referencial en TMP_',             'POR_INGESTA'),
('Carga inicial DWA',          '02-Ingenieria',   'S26',             'Carga inicial TMP_ → dimensiones y fact',            'UNICA'),
('Carga Ingesta2',             '03-Actualizacion','S30+load_csv.py', 'Carga CSVs de Ingesta2 (updates + enriquecimiento)', 'BATCH'),
('Actualización DWA',          '03-Actualizacion','S32',             'Aplica altas, bajas y modificaciones en DWA_',       'INCREMENTAL'),
('Memoria SCD Tipo 2',         '03-Actualizacion','S33',             'Registra historial de cambios en DWM_',              'INCREMENTAL'),
('Enriquecimiento world-data', '03-Actualizacion','S35',             'Incorpora datos de world-data-2023 al DWA',          'BATCH'),
('Enriquecimiento score',      '03-Actualizacion','S36',             'Incorpora customer_score al DWA',                   'BATCH'),
('Publicación DP01_VENTAS',    '04-Publicacion',  'S40',             'Crea producto de datos de ventas agregadas',         'INCREMENTAL'),
('Publicación DP02_CLIENTES',  '04-Publicacion',  'S41',             'Crea producto de datos de perfil de clientes',       'INCREMENTAL');

-- ── Linaje principal ──────────────────────────────────────────
INSERT OR REPLACE INTO MET_LINAJE (entidad_origen, entidad_destino, campo_origen, campo_destino, transformacion, script_id, fecha) VALUES
('TXT_ORDER_DETAILS', 'TMP_ORDER_DETAILS', '*', '*',             'CAST + filtro outliers',    'S15', datetime('now')),
('TMP_ORDER_DETAILS', 'DWA_FACT_VENTAS',   '*', '*',             'JOIN orders + derivados',   'S26', datetime('now')),
('TMP_CUSTOMERS',     'DWA_DIM_CLIENTE',   '*', '*',             'CAST + limpieza',           'S26', datetime('now')),
('TXT_CUSTOMER_SCORE','DWA_DIM_CLIENTE',   'score,segment', 'score,segmento', 'UPDATE',       'S36', datetime('now')),
('TXT_WORLD_DATA',    'DWA_DIM_CLIENTE',   'region,gdp', 'pais_region_mundo,pais_pib', 'UPDATE+JOIN country', 'S35', datetime('now')),
('TXT_WORLD_DATA',    'DWA_DIM_GEOGRAFIA', '*', '*',             'INSERT + CAST numeric',     'S35', datetime('now')),
('DWA_FACT_VENTAS',   'DP01_VENTAS',       '*', '*',             'GROUP BY anio/mes/prod/cli','S40', datetime('now')),
('DWA_DIM_CLIENTE',   'DP02_CLIENTES',     '*', '*',             'JOIN FACT + GROUP BY cli',  'S41', datetime('now'));

UPDATE DQM_LOG_EJECUCION
SET fecha_fin = datetime('now'), resultado = 'OK',
    mensaje = 'Metadata poblada: entidades, atributos, procesos y linaje',
    registros_proc = (SELECT COUNT(*) FROM MET_ENTIDAD) + (SELECT COUNT(*) FROM MET_PROCESO)
WHERE script_id = 'S21' AND resultado = 'RUNNING';

-- Resumen
SELECT capa, COUNT(*) AS entidades FROM MET_ENTIDAD GROUP BY capa ORDER BY capa;
