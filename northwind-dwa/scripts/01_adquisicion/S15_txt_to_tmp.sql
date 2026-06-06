-- =============================================================
-- Script ID : S15
-- Etapa     : 01 - Adquisición
-- Descripción: Copia datos de TXT_ a TMP_ con conversión de
--              tipos. Solo ejecutar si S12, S13 y S14 pasaron.
-- Fecha      : 2026-06-06
-- =============================================================

INSERT INTO DQM_LOG_EJECUCION (script_id, script_nombre, fecha_inicio, resultado)
VALUES ('S15', 'S15_txt_to_tmp.sql', datetime('now'), 'RUNNING');

-- ── Verificar que no hay rechazos antes de proceder ───────────
-- Si este SELECT devuelve filas, hay tablas rechazadas → abortar manualmente.
SELECT tabla, campo, pct_calidad, decision
FROM DQM_CONTROL_CAMPO
WHERE ingesta_id = 1 AND decision = 'RECHAZADO';

-- ── CATEGORIES ────────────────────────────────────────────────
DELETE FROM TMP_CATEGORIES;
INSERT INTO TMP_CATEGORIES (category_id, category_name, description)
SELECT
    CAST(category_id AS INTEGER),
    category_name,
    description
FROM TXT_CATEGORIES
WHERE category_id IS NOT NULL AND TRIM(category_id) != '';

INSERT INTO DQM_TRANSFORMACION (ingesta_id, origen, destino, tipo, registros_afect, fecha)
VALUES (1, 'TXT_CATEGORIES', 'TMP_CATEGORIES', 'COPIA',
        (SELECT COUNT(*) FROM TMP_CATEGORIES), datetime('now'));

-- ── CUSTOMERS ─────────────────────────────────────────────────
DELETE FROM TMP_CUSTOMERS;
INSERT INTO TMP_CUSTOMERS
SELECT customer_id, company_name, contact_name, contact_title,
       address, city, region, postal_code, country, phone, fax
FROM TXT_CUSTOMERS
WHERE customer_id IS NOT NULL AND TRIM(customer_id) != '';

INSERT INTO DQM_TRANSFORMACION (ingesta_id, origen, destino, tipo, registros_afect, fecha)
VALUES (1, 'TXT_CUSTOMERS', 'TMP_CUSTOMERS', 'COPIA',
        (SELECT COUNT(*) FROM TMP_CUSTOMERS), datetime('now'));

-- ── EMPLOYEES ─────────────────────────────────────────────────
DELETE FROM TMP_EMPLOYEES;
INSERT INTO TMP_EMPLOYEES
SELECT CAST(employee_id AS INTEGER), last_name, first_name, title, title_of_courtesy,
       birth_date, hire_date, address, city, region, postal_code, country,
       home_phone, extension, notes, CAST(reports_to AS INTEGER)
FROM TXT_EMPLOYEES
WHERE employee_id IS NOT NULL AND TRIM(employee_id) != '';

INSERT INTO DQM_TRANSFORMACION (ingesta_id, origen, destino, tipo, registros_afect, fecha)
VALUES (1, 'TXT_EMPLOYEES', 'TMP_EMPLOYEES', 'COPIA',
        (SELECT COUNT(*) FROM TMP_EMPLOYEES), datetime('now'));

-- ── SUPPLIERS ─────────────────────────────────────────────────
DELETE FROM TMP_SUPPLIERS;
INSERT INTO TMP_SUPPLIERS
SELECT CAST(supplier_id AS INTEGER), company_name, contact_name, contact_title,
       address, city, region, postal_code, country, phone, fax, homepage
FROM TXT_SUPPLIERS
WHERE supplier_id IS NOT NULL;

INSERT INTO DQM_TRANSFORMACION (ingesta_id, origen, destino, tipo, registros_afect, fecha)
VALUES (1, 'TXT_SUPPLIERS', 'TMP_SUPPLIERS', 'COPIA',
        (SELECT COUNT(*) FROM TMP_SUPPLIERS), datetime('now'));

-- ── PRODUCTS ──────────────────────────────────────────────────
DELETE FROM TMP_PRODUCTS;
INSERT INTO TMP_PRODUCTS
SELECT CAST(product_id AS INTEGER), product_name,
       CAST(supplier_id AS INTEGER), CAST(category_id AS INTEGER),
       quantity_per_unit, CAST(unit_price AS REAL),
       CAST(units_in_stock AS INTEGER), CAST(units_on_order AS INTEGER),
       CAST(reorder_level AS INTEGER), CAST(discontinued AS INTEGER)
FROM TXT_PRODUCTS
WHERE product_id IS NOT NULL
  AND CAST(unit_price AS REAL) >= 0;  -- filtrar outliers de precio

INSERT INTO DQM_TRANSFORMACION (ingesta_id, origen, destino, tipo, registros_afect, fecha)
VALUES (1, 'TXT_PRODUCTS', 'TMP_PRODUCTS', 'COPIA',
        (SELECT COUNT(*) FROM TMP_PRODUCTS), datetime('now'));

-- ── SHIPPERS ──────────────────────────────────────────────────
DELETE FROM TMP_SHIPPERS;
INSERT INTO TMP_SHIPPERS
SELECT CAST(shipper_id AS INTEGER), company_name, phone
FROM TXT_SHIPPERS WHERE shipper_id IS NOT NULL;

-- ── REGIONS ───────────────────────────────────────────────────
DELETE FROM TMP_REGIONS;
INSERT INTO TMP_REGIONS
SELECT CAST(region_id AS INTEGER), region_description
FROM TXT_REGIONS WHERE region_id IS NOT NULL;

-- ── TERRITORIES ───────────────────────────────────────────────
DELETE FROM TMP_TERRITORIES;
INSERT INTO TMP_TERRITORIES
SELECT territory_id, territory_description, CAST(region_id AS INTEGER)
FROM TXT_TERRITORIES WHERE territory_id IS NOT NULL;

-- ── ORDERS ────────────────────────────────────────────────────
DELETE FROM TMP_ORDERS;
INSERT INTO TMP_ORDERS
SELECT CAST(order_id AS INTEGER), customer_id, CAST(employee_id AS INTEGER),
       order_date, required_date, shipped_date, CAST(ship_via AS INTEGER),
       CAST(freight AS REAL), ship_name, ship_address, ship_city,
       ship_region, ship_postal_code, ship_country
FROM TXT_ORDERS
WHERE order_id IS NOT NULL AND customer_id IS NOT NULL;

INSERT INTO DQM_TRANSFORMACION (ingesta_id, origen, destino, tipo, registros_afect, fecha)
VALUES (1, 'TXT_ORDERS', 'TMP_ORDERS', 'COPIA',
        (SELECT COUNT(*) FROM TMP_ORDERS), datetime('now'));

-- ── ORDER_DETAILS ─────────────────────────────────────────────
DELETE FROM TMP_ORDER_DETAILS;
INSERT INTO TMP_ORDER_DETAILS
SELECT CAST(order_id AS INTEGER), CAST(product_id AS INTEGER),
       CAST(unit_price AS REAL), CAST(quantity AS INTEGER), CAST(discount AS REAL)
FROM TXT_ORDER_DETAILS
WHERE order_id IS NOT NULL AND product_id IS NOT NULL
  AND CAST(discount AS REAL) BETWEEN 0 AND 1;

INSERT INTO DQM_TRANSFORMACION (ingesta_id, origen, destino, tipo, registros_afect, fecha)
VALUES (1, 'TXT_ORDER_DETAILS', 'TMP_ORDER_DETAILS', 'COPIA',
        (SELECT COUNT(*) FROM TMP_ORDER_DETAILS), datetime('now'));

UPDATE DQM_LOG_EJECUCION
SET fecha_fin = datetime('now'), resultado = 'OK',
    mensaje = 'TXT_ → TMP_ completado para todas las tablas',
    registros_proc = (SELECT COUNT(*) FROM DQM_TRANSFORMACION WHERE ingesta_id = 1)
WHERE script_id = 'S15' AND resultado = 'RUNNING';
