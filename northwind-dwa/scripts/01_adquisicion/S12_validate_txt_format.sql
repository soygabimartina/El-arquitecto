-- =============================================================
-- Script ID : S12
-- Etapa     : 01 - Adquisición
-- Descripción: Valida que cada campo en TXT_ sea compatible con
--              su tipo destino en TMP_. Persiste resultados en DQM.
-- Umbrales   : pct_calidad < 95% → RECHAZADO; 95-99% → PARCIAL
-- Fecha      : 2026-06-06
-- =============================================================

INSERT INTO DQM_LOG_EJECUCION (script_id, script_nombre, fecha_inicio, resultado)
VALUES ('S12', 'S12_validate_txt_format.sql', datetime('now'), 'RUNNING');

-- ── Validar que category_id es entero ────────────────────────
INSERT INTO DQM_CONTROL_CAMPO
    (ingesta_id, tabla, campo, tipo_control, total_registros,
     registros_ok, registros_error, pct_calidad, umbral_minimo, decision, fecha)
SELECT
    1,
    'TXT_CATEGORIES',
    'category_id',
    'TIPO',
    COUNT(*),
    SUM(CASE WHEN CAST(category_id AS INTEGER) IS NOT NULL AND category_id NOT LIKE '%.%' THEN 1 ELSE 0 END),
    SUM(CASE WHEN CAST(category_id AS INTEGER) IS NULL OR category_id LIKE '%.%' THEN 1 ELSE 0 END),
    ROUND(100.0 * SUM(CASE WHEN CAST(category_id AS INTEGER) IS NOT NULL AND category_id NOT LIKE '%.%' THEN 1 ELSE 0 END) / COUNT(*), 2),
    100.0,
    CASE WHEN ROUND(100.0 * SUM(CASE WHEN CAST(category_id AS INTEGER) IS NOT NULL AND category_id NOT LIKE '%.%' THEN 1 ELSE 0 END) / COUNT(*), 2) >= 100 THEN 'ACEPTADO' ELSE 'RECHAZADO' END,
    datetime('now')
FROM TXT_CATEGORIES;

-- ── Validar que order_id es entero ───────────────────────────
INSERT INTO DQM_CONTROL_CAMPO
    (ingesta_id, tabla, campo, tipo_control, total_registros,
     registros_ok, registros_error, pct_calidad, umbral_minimo, decision, fecha)
SELECT
    1, 'TXT_ORDERS', 'order_id', 'TIPO',
    COUNT(*),
    SUM(CASE WHEN CAST(order_id AS INTEGER) IS NOT NULL AND order_id NOT LIKE '%.%' THEN 1 ELSE 0 END),
    SUM(CASE WHEN CAST(order_id AS INTEGER) IS NULL OR order_id LIKE '%.%' THEN 1 ELSE 0 END),
    ROUND(100.0 * SUM(CASE WHEN CAST(order_id AS INTEGER) IS NOT NULL AND order_id NOT LIKE '%.%' THEN 1 ELSE 0 END) / COUNT(*), 2),
    100.0,
    CASE WHEN ROUND(100.0 * SUM(CASE WHEN CAST(order_id AS INTEGER) IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 2) >= 100 THEN 'ACEPTADO' ELSE 'RECHAZADO' END,
    datetime('now')
FROM TXT_ORDERS;

-- ── Validar unit_price es número en ORDER_DETAILS ─────────────
INSERT INTO DQM_CONTROL_CAMPO
    (ingesta_id, tabla, campo, tipo_control, total_registros,
     registros_ok, registros_error, pct_calidad, umbral_minimo, decision, fecha)
SELECT
    1, 'TXT_ORDER_DETAILS', 'unit_price', 'TIPO',
    COUNT(*),
    SUM(CASE WHEN CAST(unit_price AS REAL) IS NOT NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN CAST(unit_price AS REAL) IS NULL THEN 1 ELSE 0 END),
    ROUND(100.0 * SUM(CASE WHEN CAST(unit_price AS REAL) IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 2),
    95.0,
    CASE WHEN ROUND(100.0 * SUM(CASE WHEN CAST(unit_price AS REAL) IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 2) >= 95 THEN 'ACEPTADO'
         WHEN ROUND(100.0 * SUM(CASE WHEN CAST(unit_price AS REAL) IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 2) >= 80 THEN 'PARCIAL'
         ELSE 'RECHAZADO' END,
    datetime('now')
FROM TXT_ORDER_DETAILS;

-- ── Validar discount entre 0 y 1 (outliers) ──────────────────
INSERT INTO DQM_CONTROL_CAMPO
    (ingesta_id, tabla, campo, tipo_control, total_registros,
     registros_ok, registros_error, pct_calidad, umbral_minimo, decision, fecha)
SELECT
    1, 'TXT_ORDER_DETAILS', 'discount', 'RANGO',
    COUNT(*),
    SUM(CASE WHEN CAST(discount AS REAL) >= 0 AND CAST(discount AS REAL) <= 1 THEN 1 ELSE 0 END),
    SUM(CASE WHEN CAST(discount AS REAL) < 0 OR CAST(discount AS REAL) > 1 OR discount IS NULL THEN 1 ELSE 0 END),
    ROUND(100.0 * SUM(CASE WHEN CAST(discount AS REAL) >= 0 AND CAST(discount AS REAL) <= 1 THEN 1 ELSE 0 END) / COUNT(*), 2),
    95.0,
    CASE WHEN ROUND(100.0 * SUM(CASE WHEN CAST(discount AS REAL) >= 0 AND CAST(discount AS REAL) <= 1 THEN 1 ELSE 0 END) / COUNT(*), 2) >= 95 THEN 'ACEPTADO' ELSE 'RECHAZADO' END,
    datetime('now')
FROM TXT_ORDER_DETAILS;

-- ── Validar customer_id no nulo en ORDERS ────────────────────
INSERT INTO DQM_CONTROL_CAMPO
    (ingesta_id, tabla, campo, tipo_control, total_registros,
     registros_ok, registros_error, pct_calidad, umbral_minimo, decision, fecha)
SELECT
    1, 'TXT_ORDERS', 'customer_id', 'NULOS',
    COUNT(*),
    SUM(CASE WHEN customer_id IS NOT NULL AND TRIM(customer_id) != '' THEN 1 ELSE 0 END),
    SUM(CASE WHEN customer_id IS NULL OR TRIM(customer_id) = '' THEN 1 ELSE 0 END),
    ROUND(100.0 * SUM(CASE WHEN customer_id IS NOT NULL AND TRIM(customer_id) != '' THEN 1 ELSE 0 END) / COUNT(*), 2),
    99.0,
    CASE WHEN ROUND(100.0 * SUM(CASE WHEN customer_id IS NOT NULL AND TRIM(customer_id) != '' THEN 1 ELSE 0 END) / COUNT(*), 2) >= 99 THEN 'ACEPTADO' ELSE 'RECHAZADO' END,
    datetime('now')
FROM TXT_ORDERS;

-- Resumen de resultados
SELECT tabla, campo, tipo_control, pct_calidad, decision
FROM DQM_CONTROL_CAMPO
WHERE ingesta_id = 1
ORDER BY tabla, campo;

UPDATE DQM_LOG_EJECUCION
SET fecha_fin = datetime('now'), resultado = 'OK',
    mensaje = 'Validaciones de formato ejecutadas. Ver DQM_CONTROL_CAMPO ingesta_id=1',
    registros_proc = (SELECT COUNT(*) FROM DQM_CONTROL_CAMPO WHERE ingesta_id = 1)
WHERE script_id = 'S12' AND resultado = 'RUNNING';
