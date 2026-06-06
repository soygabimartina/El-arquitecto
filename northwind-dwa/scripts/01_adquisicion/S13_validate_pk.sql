-- =============================================================
-- Script ID : S13
-- Etapa     : 01 - Adquisición
-- Descripción: Valida unicidad de PK en cada tabla TXT_ antes
--              de mover a TMP_. Persiste resultados en DQM.
-- Fecha      : 2026-06-06
-- =============================================================

INSERT INTO DQM_LOG_EJECUCION (script_id, script_nombre, fecha_inicio, resultado)
VALUES ('S13', 'S13_validate_pk.sql', datetime('now'), 'RUNNING');

-- ── CATEGORIES: category_id ────────────────────────────────────
INSERT INTO DQM_CONTROL_CAMPO
    (ingesta_id, tabla, campo, tipo_control, total_registros,
     registros_ok, registros_error, pct_calidad, umbral_minimo, decision, fecha)
SELECT 1, 'TXT_CATEGORIES', 'category_id', 'UNICIDAD',
    COUNT(*),
    COUNT(DISTINCT category_id),
    COUNT(*) - COUNT(DISTINCT category_id),
    ROUND(100.0 * COUNT(DISTINCT category_id) / COUNT(*), 2),
    100.0,
    CASE WHEN COUNT(*) = COUNT(DISTINCT category_id) THEN 'ACEPTADO' ELSE 'RECHAZADO' END,
    datetime('now')
FROM TXT_CATEGORIES WHERE category_id IS NOT NULL;

-- ── CUSTOMERS: customer_id ─────────────────────────────────────
INSERT INTO DQM_CONTROL_CAMPO
    (ingesta_id, tabla, campo, tipo_control, total_registros,
     registros_ok, registros_error, pct_calidad, umbral_minimo, decision, fecha)
SELECT 1, 'TXT_CUSTOMERS', 'customer_id', 'UNICIDAD',
    COUNT(*),
    COUNT(DISTINCT customer_id),
    COUNT(*) - COUNT(DISTINCT customer_id),
    ROUND(100.0 * COUNT(DISTINCT customer_id) / COUNT(*), 2),
    100.0,
    CASE WHEN COUNT(*) = COUNT(DISTINCT customer_id) THEN 'ACEPTADO' ELSE 'RECHAZADO' END,
    datetime('now')
FROM TXT_CUSTOMERS WHERE customer_id IS NOT NULL;

-- ── EMPLOYEES: employee_id ─────────────────────────────────────
INSERT INTO DQM_CONTROL_CAMPO
    (ingesta_id, tabla, campo, tipo_control, total_registros,
     registros_ok, registros_error, pct_calidad, umbral_minimo, decision, fecha)
SELECT 1, 'TXT_EMPLOYEES', 'employee_id', 'UNICIDAD',
    COUNT(*),
    COUNT(DISTINCT employee_id),
    COUNT(*) - COUNT(DISTINCT employee_id),
    ROUND(100.0 * COUNT(DISTINCT employee_id) / COUNT(*), 2),
    100.0,
    CASE WHEN COUNT(*) = COUNT(DISTINCT employee_id) THEN 'ACEPTADO' ELSE 'RECHAZADO' END,
    datetime('now')
FROM TXT_EMPLOYEES WHERE employee_id IS NOT NULL;

-- ── PRODUCTS: product_id ──────────────────────────────────────
INSERT INTO DQM_CONTROL_CAMPO
    (ingesta_id, tabla, campo, tipo_control, total_registros,
     registros_ok, registros_error, pct_calidad, umbral_minimo, decision, fecha)
SELECT 1, 'TXT_PRODUCTS', 'product_id', 'UNICIDAD',
    COUNT(*),
    COUNT(DISTINCT product_id),
    COUNT(*) - COUNT(DISTINCT product_id),
    ROUND(100.0 * COUNT(DISTINCT product_id) / COUNT(*), 2),
    100.0,
    CASE WHEN COUNT(*) = COUNT(DISTINCT product_id) THEN 'ACEPTADO' ELSE 'RECHAZADO' END,
    datetime('now')
FROM TXT_PRODUCTS WHERE product_id IS NOT NULL;

-- ── SUPPLIERS: supplier_id ────────────────────────────────────
INSERT INTO DQM_CONTROL_CAMPO
    (ingesta_id, tabla, campo, tipo_control, total_registros,
     registros_ok, registros_error, pct_calidad, umbral_minimo, decision, fecha)
SELECT 1, 'TXT_SUPPLIERS', 'supplier_id', 'UNICIDAD',
    COUNT(*),
    COUNT(DISTINCT supplier_id),
    COUNT(*) - COUNT(DISTINCT supplier_id),
    ROUND(100.0 * COUNT(DISTINCT supplier_id) / COUNT(*), 2),
    100.0,
    CASE WHEN COUNT(*) = COUNT(DISTINCT supplier_id) THEN 'ACEPTADO' ELSE 'RECHAZADO' END,
    datetime('now')
FROM TXT_SUPPLIERS WHERE supplier_id IS NOT NULL;

-- ── ORDERS: order_id ──────────────────────────────────────────
INSERT INTO DQM_CONTROL_CAMPO
    (ingesta_id, tabla, campo, tipo_control, total_registros,
     registros_ok, registros_error, pct_calidad, umbral_minimo, decision, fecha)
SELECT 1, 'TXT_ORDERS', 'order_id', 'UNICIDAD',
    COUNT(*),
    COUNT(DISTINCT order_id),
    COUNT(*) - COUNT(DISTINCT order_id),
    ROUND(100.0 * COUNT(DISTINCT order_id) / COUNT(*), 2),
    100.0,
    CASE WHEN COUNT(*) = COUNT(DISTINCT order_id) THEN 'ACEPTADO' ELSE 'RECHAZADO' END,
    datetime('now')
FROM TXT_ORDERS WHERE order_id IS NOT NULL;

-- ── ORDER_DETAILS: PK compuesta (order_id, product_id) ────────
INSERT INTO DQM_CONTROL_CAMPO
    (ingesta_id, tabla, campo, tipo_control, total_registros,
     registros_ok, registros_error, pct_calidad, umbral_minimo, decision, fecha)
SELECT 1, 'TXT_ORDER_DETAILS', 'order_id+product_id', 'UNICIDAD',
    COUNT(*),
    COUNT(DISTINCT order_id || '|' || product_id),
    COUNT(*) - COUNT(DISTINCT order_id || '|' || product_id),
    ROUND(100.0 * COUNT(DISTINCT order_id || '|' || product_id) / COUNT(*), 2),
    100.0,
    CASE WHEN COUNT(*) = COUNT(DISTINCT order_id || '|' || product_id) THEN 'ACEPTADO' ELSE 'RECHAZADO' END,
    datetime('now')
FROM TXT_ORDER_DETAILS WHERE order_id IS NOT NULL AND product_id IS NOT NULL;

-- Resumen
SELECT tabla, campo, tipo_control, total_registros, registros_error, pct_calidad, decision
FROM DQM_CONTROL_CAMPO
WHERE ingesta_id = 1 AND tipo_control = 'UNICIDAD'
ORDER BY tabla;

UPDATE DQM_LOG_EJECUCION
SET fecha_fin = datetime('now'), resultado = 'OK',
    mensaje = 'Validación de unicidad completada. Ver DQM_CONTROL_CAMPO tipo_control=UNICIDAD',
    registros_proc = (SELECT COUNT(*) FROM DQM_CONTROL_CAMPO WHERE ingesta_id = 1 AND tipo_control = 'UNICIDAD')
WHERE script_id = 'S13' AND resultado = 'RUNNING';
