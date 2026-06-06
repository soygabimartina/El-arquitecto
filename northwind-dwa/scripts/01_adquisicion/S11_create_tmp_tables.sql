-- =============================================================
-- Script ID : S11
-- Etapa     : 01 - Adquisición
-- Descripción: Crea las tablas TMP_ con tipos de datos correctos
--              según el DER Northwind. Incluye claves primarias.
-- Fecha      : 2026-06-06
-- =============================================================

INSERT INTO DQM_LOG_EJECUCION (script_id, script_nombre, fecha_inicio, resultado)
VALUES ('S11', 'S11_create_tmp_tables.sql', datetime('now'), 'RUNNING');

CREATE TABLE IF NOT EXISTS TMP_CATEGORIES (
    category_id   INTEGER PRIMARY KEY,
    category_name TEXT    NOT NULL,
    description   TEXT,
    picture       BLOB
);

CREATE TABLE IF NOT EXISTS TMP_CUSTOMERS (
    customer_id   TEXT    PRIMARY KEY,
    company_name  TEXT    NOT NULL,
    contact_name  TEXT,
    contact_title TEXT,
    address       TEXT,
    city          TEXT,
    region        TEXT,
    postal_code   TEXT,
    country       TEXT,
    phone         TEXT,
    fax           TEXT
);

CREATE TABLE IF NOT EXISTS TMP_EMPLOYEES (
    employee_id       INTEGER PRIMARY KEY,
    last_name         TEXT    NOT NULL,
    first_name        TEXT    NOT NULL,
    title             TEXT,
    title_of_courtesy TEXT,
    birth_date        TEXT,
    hire_date         TEXT,
    address           TEXT,
    city              TEXT,
    region            TEXT,
    postal_code       TEXT,
    country           TEXT,
    home_phone        TEXT,
    extension         TEXT,
    notes             TEXT,
    reports_to        INTEGER
);

CREATE TABLE IF NOT EXISTS TMP_SUPPLIERS (
    supplier_id   INTEGER PRIMARY KEY,
    company_name  TEXT    NOT NULL,
    contact_name  TEXT,
    contact_title TEXT,
    address       TEXT,
    city          TEXT,
    region        TEXT,
    postal_code   TEXT,
    country       TEXT,
    phone         TEXT,
    fax           TEXT,
    homepage      TEXT
);

CREATE TABLE IF NOT EXISTS TMP_PRODUCTS (
    product_id        INTEGER PRIMARY KEY,
    product_name      TEXT    NOT NULL,
    supplier_id       INTEGER,
    category_id       INTEGER,
    quantity_per_unit TEXT,
    unit_price        REAL    DEFAULT 0,
    units_in_stock    INTEGER DEFAULT 0,
    units_on_order    INTEGER DEFAULT 0,
    reorder_level     INTEGER DEFAULT 0,
    discontinued      INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS TMP_SHIPPERS (
    shipper_id    INTEGER PRIMARY KEY,
    company_name  TEXT    NOT NULL,
    phone         TEXT
);

CREATE TABLE IF NOT EXISTS TMP_REGIONS (
    region_id          INTEGER PRIMARY KEY,
    region_description TEXT    NOT NULL
);

CREATE TABLE IF NOT EXISTS TMP_TERRITORIES (
    territory_id          TEXT    PRIMARY KEY,
    territory_description TEXT    NOT NULL,
    region_id             INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS TMP_EMPLOYEE_TERRITORIES (
    employee_id  INTEGER NOT NULL,
    territory_id TEXT    NOT NULL,
    PRIMARY KEY (employee_id, territory_id)
);

CREATE TABLE IF NOT EXISTS TMP_ORDERS (
    order_id         INTEGER PRIMARY KEY,
    customer_id      TEXT    NOT NULL,
    employee_id      INTEGER,
    order_date       TEXT,
    required_date    TEXT,
    shipped_date     TEXT,
    ship_via         INTEGER,
    freight          REAL    DEFAULT 0,
    ship_name        TEXT,
    ship_address     TEXT,
    ship_city        TEXT,
    ship_region      TEXT,
    ship_postal_code TEXT,
    ship_country     TEXT
);

CREATE TABLE IF NOT EXISTS TMP_ORDER_DETAILS (
    order_id    INTEGER NOT NULL,
    product_id  INTEGER NOT NULL,
    unit_price  REAL    NOT NULL DEFAULT 0,
    quantity    INTEGER NOT NULL DEFAULT 1,
    discount    REAL    NOT NULL DEFAULT 0,
    PRIMARY KEY (order_id, product_id)
);

UPDATE DQM_LOG_EJECUCION
SET fecha_fin = datetime('now'), resultado = 'OK',
    mensaje = 'Tablas TMP_ creadas: 11', registros_proc = 11
WHERE script_id = 'S11' AND resultado = 'RUNNING';
