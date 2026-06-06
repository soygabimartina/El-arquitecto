-- =============================================================
-- Script ID : S40
-- Etapa     : 04 - Publicación
-- Descripción: Crea el Producto de Datos DP01_VENTAS.
--              Ventas agregadas por período, producto y cliente.
--              Incluye datos de Ingesta2.
-- Fecha      : 2026-06-06
-- =============================================================

INSERT INTO DQM_LOG_EJECUCION (script_id, script_nombre, fecha_inicio, resultado)
VALUES ('S40', 'S40_create_dp_ventas.sql', datetime('now'), 'RUNNING');

-- ── DP01: Ventas mensuales por producto y cliente ─────────────
DROP TABLE IF EXISTS DP01_VENTAS;

CREATE TABLE DP01_VENTAS AS
SELECT
    t.anio,
    t.trimestre,
    t.mes,
    t.nombre_mes,
    -- Producto
    f.product_id,
    p.product_name,
    p.category_name,
    -- Cliente
    f.customer_id,
    c.company_name,
    c.city          AS cliente_ciudad,
    c.country       AS cliente_pais,
    c.segmento,
    -- Empleado
    f.employee_id,
    e.full_name     AS empleado_nombre,
    -- Métricas
    COUNT(*)                        AS cantidad_lineas,
    SUM(f.quantity)                 AS unidades_vendidas,
    ROUND(SUM(f.monto_bruto), 2)    AS monto_bruto_total,
    ROUND(SUM(f.monto_neto), 2)     AS monto_neto_total,
    ROUND(AVG(f.discount) * 100, 2) AS descuento_prom_pct,
    ROUND(SUM(f.freight), 2)        AS flete_total
FROM DWA_FACT_VENTAS f
JOIN DWA_DIM_TIEMPO    t ON f.fecha_id    = t.fecha_id
JOIN DWA_DIM_PRODUCTO  p ON f.product_id  = p.product_id
JOIN DWA_DIM_CLIENTE   c ON f.customer_id = c.customer_id
JOIN DWA_DIM_EMPLEADO  e ON f.employee_id = e.employee_id
GROUP BY t.anio, t.trimestre, t.mes, t.nombre_mes,
         f.product_id, p.product_name, p.category_name,
         f.customer_id, c.company_name, c.city, c.country, c.segmento,
         f.employee_id, e.full_name;

-- Registrar en DQM
INSERT INTO DQM_TRANSFORMACION (ingesta_id, origen, destino, tipo, registros_afect, fecha)
VALUES (2, 'DWA_FACT_VENTAS+DWA_DIM_*', 'DP01_VENTAS', 'INSERT',
        (SELECT COUNT(*) FROM DP01_VENTAS), datetime('now'));

UPDATE DQM_LOG_EJECUCION
SET fecha_fin = datetime('now'), resultado = 'OK',
    mensaje = 'DP01_VENTAS creado con ' || (SELECT COUNT(*) FROM DP01_VENTAS) || ' filas',
    registros_proc = (SELECT COUNT(*) FROM DP01_VENTAS)
WHERE script_id = 'S40' AND resultado = 'RUNNING';

-- Preview
SELECT anio, nombre_mes, category_name,
       SUM(unidades_vendidas) AS unidades,
       ROUND(SUM(monto_neto_total),2) AS ingresos_netos
FROM DP01_VENTAS
GROUP BY anio, mes, nombre_mes, category_name
ORDER BY anio, mes, ingresos_netos DESC
LIMIT 20;
