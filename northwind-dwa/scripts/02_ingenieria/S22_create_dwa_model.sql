-- =============================================================
-- Script ID : S22
-- Etapa     : 02 - Ingeniería
-- Descripción: Crea el modelo dimensional del DWA (esquema
--              estrella). Incluye capas de Enriquecimiento.
-- Fecha      : 2026-06-06
-- =============================================================

INSERT INTO DQM_LOG_EJECUCION (script_id, script_nombre, fecha_inicio, resultado)
VALUES ('S22', 'S22_create_dwa_model.sql', datetime('now'), 'RUNNING');

-- ── DIM TIEMPO ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS DWA_DIM_TIEMPO (
    fecha_id     INTEGER PRIMARY KEY,  -- formato YYYYMMDD
    fecha        TEXT    NOT NULL,
    anio         INTEGER NOT NULL,
    trimestre    INTEGER NOT NULL,
    mes          INTEGER NOT NULL,
    nombre_mes   TEXT    NOT NULL,
    semana       INTEGER,
    dia          INTEGER NOT NULL,
    es_fin_semana INTEGER DEFAULT 0
);

-- ── DIM CLIENTE ───────────────────────────────────────────────
-- Enriquecida con customer_score (Ingesta2) y world-data-2023 (Ingesta2)
CREATE TABLE IF NOT EXISTS DWA_DIM_CLIENTE (
    customer_id   TEXT    PRIMARY KEY,
    company_name  TEXT    NOT NULL,
    contact_name  TEXT,
    city          TEXT,
    region        TEXT,
    country       TEXT,
    -- Enriquecimiento: customer_score (Ingesta2)
    score         REAL,
    segmento      TEXT,   -- calculado: 'ALTO'|'MEDIO'|'BAJO' según score
    -- Enriquecimiento: world-data-2023
    pais_region_mundo TEXT,
    pais_pib          REAL,
    activo            INTEGER DEFAULT 1,
    fecha_carga       TEXT
);

-- ── DIM PRODUCTO ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS DWA_DIM_PRODUCTO (
    product_id        INTEGER PRIMARY KEY,
    product_name      TEXT    NOT NULL,
    category_id       INTEGER,
    category_name     TEXT,
    supplier_id       INTEGER,
    supplier_name     TEXT,
    quantity_per_unit TEXT,
    unit_price        REAL,
    discontinued      INTEGER DEFAULT 0,
    activo            INTEGER DEFAULT 1,
    fecha_carga       TEXT
);

-- ── DIM EMPLEADO ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS DWA_DIM_EMPLEADO (
    employee_id  INTEGER PRIMARY KEY,
    full_name    TEXT    NOT NULL,
    title        TEXT,
    city         TEXT,
    country      TEXT,
    reports_to   INTEGER,
    activo       INTEGER DEFAULT 1,
    fecha_carga  TEXT
);

-- ── DIM SHIPPER ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS DWA_DIM_SHIPPER (
    shipper_id    INTEGER PRIMARY KEY,
    company_name  TEXT    NOT NULL,
    phone         TEXT,
    fecha_carga   TEXT
);

-- ── DIM GEOGRAFIA ─────────────────────────────────────────────
-- Enriquecida con world-data-2023
CREATE TABLE IF NOT EXISTS DWA_DIM_GEOGRAFIA (
    geo_id        INTEGER PRIMARY KEY AUTOINCREMENT,
    country       TEXT    NOT NULL,
    city          TEXT,
    region        TEXT,
    -- Enriquecimiento: world-data-2023
    capital       TEXT,
    region_mundo  TEXT,
    poblacion     INTEGER,
    pib_usd       REAL,
    fecha_carga   TEXT
);

-- ── FACT VENTAS ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS DWA_FACT_VENTAS (
    venta_id        INTEGER PRIMARY KEY AUTOINCREMENT,
    order_id        INTEGER NOT NULL,
    product_id      INTEGER NOT NULL,
    customer_id     TEXT    NOT NULL,
    employee_id     INTEGER,
    shipper_id      INTEGER,
    fecha_id        INTEGER NOT NULL,   -- FK → DWA_DIM_TIEMPO
    -- Métricas base
    unit_price      REAL    NOT NULL,
    quantity        INTEGER NOT NULL,
    discount        REAL    DEFAULT 0,
    freight         REAL    DEFAULT 0,
    -- Enriquecimiento: datos derivados
    monto_bruto     REAL,              -- unit_price * quantity
    monto_neto      REAL,              -- monto_bruto * (1 - discount)
    -- Control
    ingesta_id      INTEGER NOT NULL,
    fecha_carga     TEXT    NOT NULL,
    FOREIGN KEY (customer_id)  REFERENCES DWA_DIM_CLIENTE(customer_id),
    FOREIGN KEY (product_id)   REFERENCES DWA_DIM_PRODUCTO(product_id),
    FOREIGN KEY (employee_id)  REFERENCES DWA_DIM_EMPLEADO(employee_id),
    FOREIGN KEY (shipper_id)   REFERENCES DWA_DIM_SHIPPER(shipper_id),
    FOREIGN KEY (fecha_id)     REFERENCES DWA_DIM_TIEMPO(fecha_id)
);

-- ── FACT ORDENES (dimensión degenerada) ───────────────────────
CREATE TABLE IF NOT EXISTS DWA_DIM_ORDEN (
    order_id         INTEGER PRIMARY KEY,
    order_date_id    INTEGER,
    required_date_id INTEGER,
    shipped_date_id  INTEGER,
    -- Enriquecimiento
    dias_entrega     INTEGER,   -- shipped_date - order_date
    dias_demora      INTEGER,   -- shipped_date - required_date (negativo = demora)
    ship_country     TEXT,
    ship_city        TEXT,
    ingesta_id       INTEGER
);

-- Índices de performance
CREATE INDEX IF NOT EXISTS idx_fact_customer   ON DWA_FACT_VENTAS(customer_id);
CREATE INDEX IF NOT EXISTS idx_fact_product    ON DWA_FACT_VENTAS(product_id);
CREATE INDEX IF NOT EXISTS idx_fact_fecha      ON DWA_FACT_VENTAS(fecha_id);
CREATE INDEX IF NOT EXISTS idx_fact_employee   ON DWA_FACT_VENTAS(employee_id);

UPDATE DQM_LOG_EJECUCION
SET fecha_fin = datetime('now'), resultado = 'OK',
    mensaje = 'Modelo dimensional creado: 6 dimensiones + 1 fact + 1 dim orden',
    registros_proc = 8
WHERE script_id = 'S22' AND resultado = 'RUNNING';
