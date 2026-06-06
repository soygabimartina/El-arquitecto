-- =============================================================
-- Script ID : S16
-- Etapa     : 01 - Adquisición
-- Descripción: Valida integridad referencial entre tablas TMP_.
--              FK huérfanas son registradas en DQM y excluidas
--              de la carga si superan el umbral de error.
-- Fecha      : 2026-06-06
-- =============================================================

INSERT INTO DQM_LOG_EJECUCION (script_id, script_nombre, fecha_inicio, resultado)
VALUES ('S16', 'S16_validate_referential.sql', datetime('now'), 'RUNNING');

-- ── PRODUCTS → CATEGORIES ─────────────────────────────────────
INSERT INTO DQM_CONTROL_CAMPO
    (ingesta_id, tabla, campo, tipo_control, total_registros,
     registros_ok, registros_error, pct_calidad, umbral_minimo, decision, fecha)
SELECT
    1, 'TMP_PRODUCTS', 'category_id', 'RI',
    COUNT(*),
    SUM(CASE WHEN c.category_id IS NOT NULL OR p.category_id IS NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN c.category_id IS NULL AND p.category_id IS NOT NULL THEN 1 ELSE 0 END),
    ROUND(100.0 * SUM(CASE WHEN c.category_id IS NOT NULL OR p.category_id IS NULL THEN 1 ELSE 0 END) / COUNT(*), 2),
    95.0,
    CASE WHEN ROUND(100.0 * SUM(CASE WHEN c.category_id IS NOT NULL OR p.category_id IS NULL THEN 1 ELSE 0 END) / COUNT(*), 2) >= 95
         THEN 'ACEPTADO' ELSE 'RECHAZADO' END,
    datetime('now')
FROM TMP_PRODUCTS p
LEFT JOIN TMP_CATEGORIES c ON p.category_id = c.category_id;

-- ── PRODUCTS → SUPPLIERS ──────────────────────────────────────
INSERT INTO DQM_CONTROL_CAMPO
    (ingesta_id, tabla, campo, tipo_control, total_registros,
     registros_ok, registros_error, pct_calidad, umbral_minimo, decision, fecha)
SELECT
    1, 'TMP_PRODUCTS', 'supplier_id', 'RI',
    COUNT(*),
    SUM(CASE WHEN s.supplier_id IS NOT NULL OR p.supplier_id IS NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN s.supplier_id IS NULL AND p.supplier_id IS NOT NULL THEN 1 ELSE 0 END),
    ROUND(100.0 * SUM(CASE WHEN s.supplier_id IS NOT NULL OR p.supplier_id IS NULL THEN 1 ELSE 0 END) / COUNT(*), 2),
    95.0,
    CASE WHEN ROUND(100.0 * SUM(CASE WHEN s.supplier_id IS NOT NULL OR p.supplier_id IS NULL THEN 1 ELSE 0 END) / COUNT(*), 2) >= 95
         THEN 'ACEPTADO' ELSE 'RECHAZADO' END,
    datetime('now')
FROM TMP_PRODUCTS p
LEFT JOIN TMP_SUPPLIERS s ON p.supplier_id = s.supplier_id;

-- ── ORDERS → CUSTOMERS ────────────────────────────────────────
INSERT INTO DQM_CONTROL_CAMPO
    (ingesta_id, tabla, campo, tipo_control, total_registros,
     registros_ok, registros_error, pct_calidad, umbral_minimo, decision, fecha)
SELECT
    1, 'TMP_ORDERS', 'customer_id', 'RI',
    COUNT(*),
    SUM(CASE WHEN c.customer_id IS NOT NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN c.customer_id IS NULL THEN 1 ELSE 0 END),
    ROUND(100.0 * SUM(CASE WHEN c.customer_id IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 2),
    99.0,
    CASE WHEN ROUND(100.0 * SUM(CASE WHEN c.customer_id IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 2) >= 99
         THEN 'ACEPTADO' ELSE 'RECHAZADO' END,
    datetime('now')
FROM TMP_ORDERS o
LEFT JOIN TMP_CUSTOMERS c ON o.customer_id = c.customer_id;

-- ── ORDERS → EMPLOYEES ────────────────────────────────────────
INSERT INTO DQM_CONTROL_CAMPO
    (ingesta_id, tabla, campo, tipo_control, total_registros,
     registros_ok, registros_error, pct_calidad, umbral_minimo, decision, fecha)
SELECT
    1, 'TMP_ORDERS', 'employee_id', 'RI',
    COUNT(*),
    SUM(CASE WHEN e.employee_id IS NOT NULL OR o.employee_id IS NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN e.employee_id IS NULL AND o.employee_id IS NOT NULL THEN 1 ELSE 0 END),
    ROUND(100.0 * SUM(CASE WHEN e.employee_id IS NOT NULL OR o.employee_id IS NULL THEN 1 ELSE 0 END) / COUNT(*), 2),
    95.0,
    CASE WHEN ROUND(100.0 * SUM(CASE WHEN e.employee_id IS NOT NULL OR o.employee_id IS NULL THEN 1 ELSE 0 END) / COUNT(*), 2) >= 95
         THEN 'ACEPTADO' ELSE 'RECHAZADO' END,
    datetime('now')
FROM TMP_ORDERS o
LEFT JOIN TMP_EMPLOYEES e ON o.employee_id = e.employee_id;

-- ── ORDERS → SHIPPERS ─────────────────────────────────────────
INSERT INTO DQM_CONTROL_CAMPO
    (ingesta_id, tabla, campo, tipo_control, total_registros,
     registros_ok, registros_error, pct_calidad, umbral_minimo, decision, fecha)
SELECT
    1, 'TMP_ORDERS', 'ship_via', 'RI',
    COUNT(*),
    SUM(CASE WHEN s.shipper_id IS NOT NULL OR o.ship_via IS NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN s.shipper_id IS NULL AND o.ship_via IS NOT NULL THEN 1 ELSE 0 END),
    ROUND(100.0 * SUM(CASE WHEN s.shipper_id IS NOT NULL OR o.ship_via IS NULL THEN 1 ELSE 0 END) / COUNT(*), 2),
    95.0,
    CASE WHEN ROUND(100.0 * SUM(CASE WHEN s.shipper_id IS NOT NULL OR o.ship_via IS NULL THEN 1 ELSE 0 END) / COUNT(*), 2) >= 95
         THEN 'ACEPTADO' ELSE 'RECHAZADO' END,
    datetime('now')
FROM TMP_ORDERS o
LEFT JOIN TMP_SHIPPERS s ON o.ship_via = s.shipper_id;

-- ── ORDER_DETAILS → ORDERS ────────────────────────────────────
INSERT INTO DQM_CONTROL_CAMPO
    (ingesta_id, tabla, campo, tipo_control, total_registros,
     registros_ok, registros_error, pct_calidad, umbral_minimo, decision, fecha)
SELECT
    1, 'TMP_ORDER_DETAILS', 'order_id', 'RI',
    COUNT(*),
    SUM(CASE WHEN o.order_id IS NOT NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN o.order_id IS NULL THEN 1 ELSE 0 END),
    ROUND(100.0 * SUM(CASE WHEN o.order_id IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 2),
    99.0,
    CASE WHEN ROUND(100.0 * SUM(CASE WHEN o.order_id IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 2) >= 99
         THEN 'ACEPTADO' ELSE 'RECHAZADO' END,
    datetime('now')
FROM TMP_ORDER_DETAILS od
LEFT JOIN TMP_ORDERS o ON od.order_id = o.order_id;

-- ── ORDER_DETAILS → PRODUCTS ──────────────────────────────────
INSERT INTO DQM_CONTROL_CAMPO
    (ingesta_id, tabla, campo, tipo_control, total_registros,
     registros_ok, registros_error, pct_calidad, umbral_minimo, decision, fecha)
SELECT
    1, 'TMP_ORDER_DETAILS', 'product_id', 'RI',
    COUNT(*),
    SUM(CASE WHEN p.product_id IS NOT NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN p.product_id IS NULL THEN 1 ELSE 0 END),
    ROUND(100.0 * SUM(CASE WHEN p.product_id IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 2),
    99.0,
    CASE WHEN ROUND(100.0 * SUM(CASE WHEN p.product_id IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 2) >= 99
         THEN 'ACEPTADO' ELSE 'RECHAZADO' END,
    datetime('now')
FROM TMP_ORDER_DETAILS od
LEFT JOIN TMP_PRODUCTS p ON od.product_id = p.product_id;

-- Resumen de integridad referencial
SELECT tabla, campo, tipo_control, registros_error, pct_calidad, decision
FROM DQM_CONTROL_CAMPO
WHERE ingesta_id = 1 AND tipo_control = 'RI'
ORDER BY pct_calidad ASC;

-- Lista de FK huérfanas en ORDER_DETAILS (para auditoría)
SELECT 'OD sin orden válida' AS problema, COUNT(*) AS cantidad
FROM TMP_ORDER_DETAILS od LEFT JOIN TMP_ORDERS o ON od.order_id = o.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'OD sin producto válido', COUNT(*)
FROM TMP_ORDER_DETAILS od LEFT JOIN TMP_PRODUCTS p ON od.product_id = p.product_id
WHERE p.product_id IS NULL;

UPDATE DQM_LOG_EJECUCION
SET fecha_fin = datetime('now'), resultado = 'OK',
    mensaje = 'Validación de integridad referencial completada',
    registros_proc = (SELECT COUNT(*) FROM DQM_CONTROL_CAMPO WHERE ingesta_id = 1 AND tipo_control = 'RI')
WHERE script_id = 'S16' AND resultado = 'RUNNING';
