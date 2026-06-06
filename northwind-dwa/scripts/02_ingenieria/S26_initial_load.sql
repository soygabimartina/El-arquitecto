-- =============================================================
-- Script ID : S26
-- Etapa     : 02 - Ingeniería
-- Descripción: Carga inicial de TMP_ → DWA_. Respeta orden de
--              prevalencia: DIM antes que FACT.
-- Fecha      : 2026-06-06
-- =============================================================

INSERT INTO DQM_LOG_EJECUCION (script_id, script_nombre, fecha_inicio, resultado)
VALUES ('S26', 'S26_initial_load.sql', datetime('now'), 'RUNNING');

-- ── 1. DIM TIEMPO (poblar con fechas de orders) ───────────────
INSERT OR IGNORE INTO DWA_DIM_TIEMPO (fecha_id, fecha, anio, trimestre, mes, nombre_mes, semana, dia, es_fin_semana)
SELECT DISTINCT
    CAST(REPLACE(SUBSTR(order_date,1,10), '-', '') AS INTEGER),
    SUBSTR(order_date,1,10),
    CAST(SUBSTR(order_date,1,4) AS INTEGER),
    CASE CAST(SUBSTR(order_date,6,2) AS INTEGER)
        WHEN 1 THEN 1 WHEN 2 THEN 1 WHEN 3 THEN 1
        WHEN 4 THEN 2 WHEN 5 THEN 2 WHEN 6 THEN 2
        WHEN 7 THEN 3 WHEN 8 THEN 3 WHEN 9 THEN 3
        ELSE 4 END,
    CAST(SUBSTR(order_date,6,2) AS INTEGER),
    CASE CAST(SUBSTR(order_date,6,2) AS INTEGER)
        WHEN 1 THEN 'Enero' WHEN 2 THEN 'Febrero' WHEN 3 THEN 'Marzo'
        WHEN 4 THEN 'Abril' WHEN 5 THEN 'Mayo' WHEN 6 THEN 'Junio'
        WHEN 7 THEN 'Julio' WHEN 8 THEN 'Agosto' WHEN 9 THEN 'Septiembre'
        WHEN 10 THEN 'Octubre' WHEN 11 THEN 'Noviembre' ELSE 'Diciembre' END,
    CAST(strftime('%W', SUBSTR(order_date,1,10)) AS INTEGER),
    CAST(SUBSTR(order_date,9,2) AS INTEGER),
    CASE WHEN strftime('%w', SUBSTR(order_date,1,10)) IN ('0','6') THEN 1 ELSE 0 END
FROM TMP_ORDERS
WHERE order_date IS NOT NULL AND LENGTH(order_date) >= 10;

-- ── 2. DIM SHIPPER ────────────────────────────────────────────
INSERT OR IGNORE INTO DWA_DIM_SHIPPER (shipper_id, company_name, phone, fecha_carga)
SELECT shipper_id, company_name, phone, datetime('now')
FROM TMP_SHIPPERS;

-- ── 3. DIM EMPLEADO ───────────────────────────────────────────
INSERT OR IGNORE INTO DWA_DIM_EMPLEADO (employee_id, full_name, title, city, country, reports_to, fecha_carga)
SELECT employee_id,
       first_name || ' ' || last_name,
       title, city, country, reports_to,
       datetime('now')
FROM TMP_EMPLOYEES;

-- ── 4. DIM PRODUCTO (denormalizada con categoría y proveedor) ──
INSERT OR IGNORE INTO DWA_DIM_PRODUCTO
    (product_id, product_name, category_id, category_name, supplier_id, supplier_name,
     quantity_per_unit, unit_price, discontinued, fecha_carga)
SELECT p.product_id, p.product_name,
       p.category_id, c.category_name,
       p.supplier_id, s.company_name,
       p.quantity_per_unit, p.unit_price, p.discontinued,
       datetime('now')
FROM TMP_PRODUCTS p
LEFT JOIN TMP_CATEGORIES c ON p.category_id = c.category_id
LEFT JOIN TMP_SUPPLIERS  s ON p.supplier_id = s.supplier_id;

-- ── 5. DIM CLIENTE ────────────────────────────────────────────
INSERT OR IGNORE INTO DWA_DIM_CLIENTE
    (customer_id, company_name, contact_name, city, region, country, activo, fecha_carga)
SELECT customer_id, company_name, contact_name, city, region, country, 1, datetime('now')
FROM TMP_CUSTOMERS;

-- ── 6. DIM ORDEN ──────────────────────────────────────────────
INSERT OR IGNORE INTO DWA_DIM_ORDEN
    (order_id, order_date_id, shipped_date_id,
     dias_entrega, ship_country, ship_city, ingesta_id)
SELECT
    order_id,
    CAST(REPLACE(SUBSTR(order_date,1,10), '-', '') AS INTEGER),
    CAST(REPLACE(SUBSTR(COALESCE(shipped_date, order_date),1,10), '-', '') AS INTEGER),
    CASE WHEN shipped_date IS NOT NULL
         THEN CAST(julianday(SUBSTR(shipped_date,1,10)) - julianday(SUBSTR(order_date,1,10)) AS INTEGER)
         ELSE NULL END,
    ship_country, ship_city, 1
FROM TMP_ORDERS;

-- ── 7. FACT VENTAS ────────────────────────────────────────────
INSERT INTO DWA_FACT_VENTAS
    (order_id, product_id, customer_id, employee_id, shipper_id, fecha_id,
     unit_price, quantity, discount, freight,
     monto_bruto, monto_neto, ingesta_id, fecha_carga)
SELECT
    od.order_id,
    od.product_id,
    o.customer_id,
    o.employee_id,
    o.ship_via,
    CAST(REPLACE(SUBSTR(o.order_date,1,10), '-', '') AS INTEGER),
    od.unit_price,
    od.quantity,
    od.discount,
    o.freight,
    -- Enriquecimiento
    ROUND(od.unit_price * od.quantity, 2),
    ROUND(od.unit_price * od.quantity * (1 - od.discount), 2),
    1,
    datetime('now')
FROM TMP_ORDER_DETAILS od
JOIN TMP_ORDERS o ON od.order_id = o.order_id
WHERE o.customer_id IN (SELECT customer_id FROM DWA_DIM_CLIENTE)
  AND od.product_id  IN (SELECT product_id  FROM DWA_DIM_PRODUCTO);

-- Registrar transformación en DQM
INSERT INTO DQM_TRANSFORMACION (ingesta_id, origen, destino, tipo, registros_afect, fecha)
VALUES (1, 'TMP_ORDER_DETAILS+TMP_ORDERS', 'DWA_FACT_VENTAS', 'INSERT',
        (SELECT COUNT(*) FROM DWA_FACT_VENTAS WHERE ingesta_id = 1), datetime('now'));

UPDATE DQM_LOG_EJECUCION
SET fecha_fin = datetime('now'), resultado = 'OK',
    mensaje = 'Carga inicial completada. Fact: ' || (SELECT COUNT(*) FROM DWA_FACT_VENTAS) || ' filas',
    registros_proc = (SELECT COUNT(*) FROM DWA_FACT_VENTAS)
WHERE script_id = 'S26' AND resultado = 'RUNNING';
