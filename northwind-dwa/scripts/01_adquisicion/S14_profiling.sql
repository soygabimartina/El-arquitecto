-- =============================================================
-- Script ID : S14
-- Etapa     : 01 - Adquisición
-- Descripción: Perfilado de datos sobre TXT_: total filas,
--              nulos, duplicados. Persiste en DQM_PERFILADO.
-- Fecha      : 2026-06-06
-- =============================================================

INSERT INTO DQM_LOG_EJECUCION (script_id, script_nombre, fecha_inicio, resultado)
VALUES ('S14', 'S14_profiling.sql', datetime('now'), 'RUNNING');

-- Perfilado TXT_CUSTOMERS
INSERT INTO DQM_PERFILADO (ingesta_id, tabla, total_filas, total_columnas, nulos_total, duplicados_pk, fecha)
SELECT 1, 'TXT_CUSTOMERS',
    COUNT(*),
    11,
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) +
    SUM(CASE WHEN company_name IS NULL THEN 1 ELSE 0 END) +
    SUM(CASE WHEN city IS NULL THEN 1 ELSE 0 END) +
    SUM(CASE WHEN country IS NULL THEN 1 ELSE 0 END),
    (SELECT COUNT(*) - COUNT(DISTINCT customer_id) FROM TXT_CUSTOMERS),
    datetime('now')
FROM TXT_CUSTOMERS;

-- Perfilado TXT_ORDERS
INSERT INTO DQM_PERFILADO (ingesta_id, tabla, total_filas, total_columnas, nulos_total, duplicados_pk, fecha)
SELECT 1, 'TXT_ORDERS',
    COUNT(*),
    14,
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) +
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) +
    SUM(CASE WHEN order_date IS NULL THEN 1 ELSE 0 END),
    (SELECT COUNT(*) - COUNT(DISTINCT order_id) FROM TXT_ORDERS),
    datetime('now')
FROM TXT_ORDERS;

-- Perfilado TXT_ORDER_DETAILS
INSERT INTO DQM_PERFILADO (ingesta_id, tabla, total_filas, total_columnas, nulos_total, duplicados_pk, fecha)
SELECT 1, 'TXT_ORDER_DETAILS',
    COUNT(*),
    5,
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) +
    SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END) +
    SUM(CASE WHEN unit_price IS NULL THEN 1 ELSE 0 END),
    (SELECT COUNT(*) - COUNT(DISTINCT order_id || '-' || product_id) FROM TXT_ORDER_DETAILS),
    datetime('now')
FROM TXT_ORDER_DETAILS;

-- Perfilado TXT_PRODUCTS
INSERT INTO DQM_PERFILADO (ingesta_id, tabla, total_filas, total_columnas, nulos_total, duplicados_pk, fecha)
SELECT 1, 'TXT_PRODUCTS',
    COUNT(*),
    10,
    SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END) +
    SUM(CASE WHEN product_name IS NULL THEN 1 ELSE 0 END),
    (SELECT COUNT(*) - COUNT(DISTINCT product_id) FROM TXT_PRODUCTS),
    datetime('now')
FROM TXT_PRODUCTS;

-- Vista del perfilado completo
SELECT tabla, total_filas, nulos_total, duplicados_pk, fecha
FROM DQM_PERFILADO
WHERE ingesta_id = 1
ORDER BY tabla;

UPDATE DQM_LOG_EJECUCION
SET fecha_fin = datetime('now'), resultado = 'OK',
    mensaje = 'Perfilado completado. Ver DQM_PERFILADO ingesta_id=1',
    registros_proc = (SELECT COUNT(*) FROM DQM_PERFILADO WHERE ingesta_id = 1)
WHERE script_id = 'S14' AND resultado = 'RUNNING';
