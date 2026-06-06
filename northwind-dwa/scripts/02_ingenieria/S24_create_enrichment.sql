-- =============================================================
-- Script ID : S24
-- Etapa     : 02 - Ingeniería
-- Descripción: Crea vistas analíticas (VW_) sobre el modelo
--              dimensional. Facilitan la conexión desde Power BI
--              y exponen los campos de enriquecimiento.
-- Fecha      : 2026-06-06
-- =============================================================

INSERT INTO DQM_LOG_EJECUCION (script_id, script_nombre, fecha_inicio, resultado)
VALUES ('S24', 'S24_create_enrichment.sql', datetime('now'), 'RUNNING');

-- ── Vista desnormalizada completa (para Power BI) ────────────
DROP VIEW IF EXISTS VW_FACT_VENTAS_COMPLETA;
CREATE VIEW VW_FACT_VENTAS_COMPLETA AS
SELECT
    -- Tiempo
    t.fecha,
    t.anio,
    t.trimestre,
    t.mes,
    t.nombre_mes,
    t.semana,
    t.es_fin_semana,
    -- Producto
    p.product_id,
    p.product_name,
    p.category_name,
    p.supplier_name,
    p.unit_price  AS precio_lista,
    p.discontinued,
    -- Cliente
    c.customer_id,
    c.company_name,
    c.city         AS cliente_ciudad,
    c.country      AS cliente_pais,
    c.segmento,
    c.score,
    c.pais_region_mundo,
    c.pais_pib,
    -- Empleado
    e.employee_id,
    e.full_name    AS empleado_nombre,
    e.title        AS empleado_cargo,
    -- Shipper
    s.company_name AS shipper_nombre,
    -- Orden
    f.order_id,
    o.dias_entrega,
    o.dias_demora,
    o.ship_country,
    -- Métricas
    f.quantity,
    f.unit_price   AS precio_venta,
    f.discount,
    f.freight,
    f.monto_bruto,
    f.monto_neto,
    -- Control
    f.ingesta_id
FROM DWA_FACT_VENTAS f
JOIN  DWA_DIM_TIEMPO    t ON f.fecha_id    = t.fecha_id
JOIN  DWA_DIM_PRODUCTO  p ON f.product_id  = p.product_id
JOIN  DWA_DIM_CLIENTE   c ON f.customer_id = c.customer_id
LEFT JOIN DWA_DIM_EMPLEADO e ON f.employee_id = e.employee_id
LEFT JOIN DWA_DIM_SHIPPER  s ON f.shipper_id  = s.shipper_id
LEFT JOIN DWA_DIM_ORDEN    o ON f.order_id    = o.order_id;

-- ── Vista KPIs por categoría y mes ───────────────────────────
DROP VIEW IF EXISTS VW_KPI_CATEGORIA_MES;
CREATE VIEW VW_KPI_CATEGORIA_MES AS
SELECT
    t.anio,
    t.mes,
    t.nombre_mes,
    p.category_name,
    COUNT(*)                          AS lineas_venta,
    SUM(f.quantity)                   AS unidades_vendidas,
    ROUND(SUM(f.monto_bruto), 2)      AS monto_bruto,
    ROUND(SUM(f.monto_neto),  2)      AS monto_neto,
    ROUND(AVG(f.discount) * 100, 2)   AS descuento_prom_pct,
    COUNT(DISTINCT f.customer_id)     AS clientes_activos,
    COUNT(DISTINCT f.order_id)        AS total_pedidos
FROM DWA_FACT_VENTAS f
JOIN DWA_DIM_TIEMPO   t ON f.fecha_id   = t.fecha_id
JOIN DWA_DIM_PRODUCTO p ON f.product_id = p.product_id
GROUP BY t.anio, t.mes, t.nombre_mes, p.category_name;

-- ── Vista completitud del enriquecimiento ────────────────────
DROP VIEW IF EXISTS VW_ENRIQUECIMIENTO_STATUS;
CREATE VIEW VW_ENRIQUECIMIENTO_STATUS AS
SELECT
    'DWA_DIM_CLIENTE'              AS entidad,
    'score'                        AS campo_enriquecido,
    COUNT(*)                       AS total,
    SUM(CASE WHEN score IS NOT NULL THEN 1 ELSE 0 END) AS completados,
    ROUND(100.0 * SUM(CASE WHEN score IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_completo
FROM DWA_DIM_CLIENTE
UNION ALL
SELECT
    'DWA_DIM_CLIENTE', 'pais_pib',
    COUNT(*),
    SUM(CASE WHEN pais_pib IS NOT NULL THEN 1 ELSE 0 END),
    ROUND(100.0 * SUM(CASE WHEN pais_pib IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 1)
FROM DWA_DIM_CLIENTE
UNION ALL
SELECT
    'DWA_DIM_GEOGRAFIA', 'pib_usd',
    COUNT(*),
    SUM(CASE WHEN pib_usd IS NOT NULL THEN 1 ELSE 0 END),
    ROUND(100.0 * SUM(CASE WHEN pib_usd IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 1)
FROM DWA_DIM_GEOGRAFIA
UNION ALL
SELECT
    'DWA_FACT_VENTAS', 'monto_neto',
    COUNT(*),
    SUM(CASE WHEN monto_neto IS NOT NULL THEN 1 ELSE 0 END),
    ROUND(100.0 * SUM(CASE WHEN monto_neto IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 1)
FROM DWA_FACT_VENTAS;

UPDATE DQM_LOG_EJECUCION
SET fecha_fin = datetime('now'), resultado = 'OK',
    mensaje = 'Vistas de enriquecimiento creadas: VW_FACT_VENTAS_COMPLETA, VW_KPI_CATEGORIA_MES, VW_ENRIQUECIMIENTO_STATUS',
    registros_proc = 3
WHERE script_id = 'S24' AND resultado = 'RUNNING';
