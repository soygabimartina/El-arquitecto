-- =============================================================
-- Script ID : S32
-- Etapa     : 03 - Actualización
-- Descripción: Actualiza el DWA con Ingesta2. Maneja altas,
--              bajas y modificaciones. Guarda historia en DWM_.
-- Fecha      : 2026-06-06
-- =============================================================

INSERT INTO DQM_LOG_EJECUCION (script_id, script_nombre, fecha_inicio, resultado)
VALUES ('S32', 'S32_update_dwa.sql', datetime('now'), 'RUNNING');

-- ── CLIENTES: detectar modificaciones → registrar en DWM ──────
-- (el script S33 maneja el DWM; aquí solo actualizamos DWA)

-- Actualizar clientes modificados
UPDATE DWA_DIM_CLIENTE
SET company_name  = (SELECT company_name FROM TMP_CUSTOMERS t WHERE t.customer_id = DWA_DIM_CLIENTE.customer_id),
    contact_name  = (SELECT contact_name FROM TMP_CUSTOMERS t WHERE t.customer_id = DWA_DIM_CLIENTE.customer_id),
    city          = (SELECT city    FROM TMP_CUSTOMERS t WHERE t.customer_id = DWA_DIM_CLIENTE.customer_id),
    country       = (SELECT country FROM TMP_CUSTOMERS t WHERE t.customer_id = DWA_DIM_CLIENTE.customer_id),
    region        = (SELECT region  FROM TMP_CUSTOMERS t WHERE t.customer_id = DWA_DIM_CLIENTE.customer_id),
    fecha_carga   = datetime('now')
WHERE customer_id IN (SELECT customer_id FROM TMP_CUSTOMERS);

-- Insertar clientes nuevos (alta)
INSERT OR IGNORE INTO DWA_DIM_CLIENTE
    (customer_id, company_name, contact_name, city, region, country, activo, fecha_carga)
SELECT t.customer_id, t.company_name, t.contact_name, t.city, t.region, t.country, 1, datetime('now')
FROM TMP_CUSTOMERS t
WHERE t.customer_id NOT IN (SELECT customer_id FROM DWA_DIM_CLIENTE);

-- ── PRODUCTOS: actualizar ─────────────────────────────────────
UPDATE DWA_DIM_PRODUCTO
SET product_name = (SELECT product_name FROM TMP_PRODUCTS p WHERE p.product_id = DWA_DIM_PRODUCTO.product_id),
    unit_price   = (SELECT unit_price   FROM TMP_PRODUCTS p WHERE p.product_id = DWA_DIM_PRODUCTO.product_id),
    discontinued = (SELECT discontinued FROM TMP_PRODUCTS p WHERE p.product_id = DWA_DIM_PRODUCTO.product_id),
    fecha_carga  = datetime('now')
WHERE product_id IN (SELECT product_id FROM TMP_PRODUCTS);

-- ── ORDERS: altas de nuevas órdenes ───────────────────────────
-- Nuevas fechas en DIM_TIEMPO
INSERT OR IGNORE INTO DWA_DIM_TIEMPO (fecha_id, fecha, anio, trimestre, mes, nombre_mes, dia)
SELECT DISTINCT
    CAST(REPLACE(SUBSTR(order_date,1,10), '-', '') AS INTEGER),
    SUBSTR(order_date,1,10),
    CAST(SUBSTR(order_date,1,4) AS INTEGER),
    CASE CAST(SUBSTR(order_date,6,2) AS INTEGER) WHEN 1 THEN 1 WHEN 2 THEN 1 WHEN 3 THEN 1
        WHEN 4 THEN 2 WHEN 5 THEN 2 WHEN 6 THEN 2 WHEN 7 THEN 3 WHEN 8 THEN 3 WHEN 9 THEN 3 ELSE 4 END,
    CAST(SUBSTR(order_date,6,2) AS INTEGER),
    CASE CAST(SUBSTR(order_date,6,2) AS INTEGER) WHEN 1 THEN 'Enero' WHEN 2 THEN 'Febrero'
        WHEN 3 THEN 'Marzo' WHEN 4 THEN 'Abril' WHEN 5 THEN 'Mayo' WHEN 6 THEN 'Junio'
        WHEN 7 THEN 'Julio' WHEN 8 THEN 'Agosto' WHEN 9 THEN 'Septiembre'
        WHEN 10 THEN 'Octubre' WHEN 11 THEN 'Noviembre' ELSE 'Diciembre' END,
    CAST(SUBSTR(order_date,9,2) AS INTEGER)
FROM TMP_ORDERS o2
WHERE CAST(REPLACE(SUBSTR(order_date,1,10), '-', '') AS INTEGER)
      NOT IN (SELECT fecha_id FROM DWA_DIM_TIEMPO);

-- Nuevas órdenes en FACT
INSERT INTO DWA_FACT_VENTAS
    (order_id, product_id, customer_id, employee_id, shipper_id, fecha_id,
     unit_price, quantity, discount, freight, monto_bruto, monto_neto, ingesta_id, fecha_carga)
SELECT
    od.order_id, od.product_id, o.customer_id, o.employee_id, o.ship_via,
    CAST(REPLACE(SUBSTR(o.order_date,1,10), '-', '') AS INTEGER),
    od.unit_price, od.quantity, od.discount, o.freight,
    ROUND(od.unit_price * od.quantity, 2),
    ROUND(od.unit_price * od.quantity * (1 - od.discount), 2),
    2, datetime('now')
FROM TMP_ORDER_DETAILS od
JOIN TMP_ORDERS o ON od.order_id = o.order_id
WHERE od.order_id NOT IN (SELECT DISTINCT order_id FROM DWA_FACT_VENTAS);

INSERT INTO DQM_TRANSFORMACION (ingesta_id, origen, destino, tipo, registros_afect, fecha)
VALUES (2, 'TMP_ORDERS+TMP_ORDER_DETAILS', 'DWA_FACT_VENTAS', 'INSERT',
        (SELECT COUNT(*) FROM DWA_FACT_VENTAS WHERE ingesta_id = 2), datetime('now'));

UPDATE DQM_LOG_EJECUCION
SET fecha_fin = datetime('now'), resultado = 'OK',
    mensaje = 'Actualización DWA completada (ingesta_id=2)',
    registros_proc = (SELECT COUNT(*) FROM DWA_FACT_VENTAS WHERE ingesta_id = 2)
WHERE script_id = 'S32' AND resultado = 'RUNNING';
