-- =============================================================
-- Script ID : S10
-- Etapa     : 01 - Adquisición
-- Descripción: Crea las tablas TXT_ con todos los campos en
--              formato TEXT. Son el destino directo de los CSV.
-- Fecha      : 2026-06-06
-- =============================================================

INSERT INTO DQM_LOG_EJECUCION (script_id, script_nombre, fecha_inicio, resultado)
VALUES ('S10', 'S10_create_txt_tables.sql', datetime('now'), 'RUNNING');

-- ── TXT_CATEGORIES ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS TXT_CATEGORIES (
    category_id   TEXT,
    category_name TEXT,
    description   TEXT,
    picture       TEXT
);

-- ── TXT_CUSTOMERS ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS TXT_CUSTOMERS (
    customer_id   TEXT,
    company_name  TEXT,
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

-- ── TXT_EMPLOYEES ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS TXT_EMPLOYEES (
    employee_id       TEXT,
    last_name         TEXT,
    first_name        TEXT,
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
    photo             TEXT,
    notes             TEXT,
    reports_to        TEXT,
    photo_path        TEXT
);

-- ── TXT_SUPPLIERS ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS TXT_SUPPLIERS (
    supplier_id   TEXT,
    company_name  TEXT,
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

-- ── TXT_PRODUCTS ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS TXT_PRODUCTS (
    product_id        TEXT,
    product_name      TEXT,
    supplier_id       TEXT,
    category_id       TEXT,
    quantity_per_unit TEXT,
    unit_price        TEXT,
    units_in_stock    TEXT,
    units_on_order    TEXT,
    reorder_level     TEXT,
    discontinued      TEXT
);

-- ── TXT_SHIPPERS ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS TXT_SHIPPERS (
    shipper_id    TEXT,
    company_name  TEXT,
    phone         TEXT
);

-- ── TXT_ORDERS ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS TXT_ORDERS (
    order_id         TEXT,
    customer_id      TEXT,
    employee_id      TEXT,
    order_date       TEXT,
    required_date    TEXT,
    shipped_date     TEXT,
    ship_via         TEXT,
    freight          TEXT,
    ship_name        TEXT,
    ship_address     TEXT,
    ship_city        TEXT,
    ship_region      TEXT,
    ship_postal_code TEXT,
    ship_country     TEXT
);

-- ── TXT_ORDER_DETAILS ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS TXT_ORDER_DETAILS (
    order_id    TEXT,
    product_id  TEXT,
    unit_price  TEXT,
    quantity    TEXT,
    discount    TEXT
);

-- ── TXT_TERRITORIES ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS TXT_TERRITORIES (
    territory_id          TEXT,
    territory_description TEXT,
    region_id             TEXT
);

-- ── TXT_REGIONS ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS TXT_REGIONS (
    region_id          TEXT,
    region_description TEXT
);

-- ── TXT_EMPLOYEE_TERRITORIES ──────────────────────────────────
CREATE TABLE IF NOT EXISTS TXT_EMPLOYEE_TERRITORIES (
    employee_id  TEXT,
    territory_id TEXT
);

UPDATE DQM_LOG_EJECUCION
SET fecha_fin = datetime('now'), resultado = 'OK',
    mensaje = 'Tablas TXT_ creadas: 11', registros_proc = 11
WHERE script_id = 'S10' AND resultado = 'RUNNING';
