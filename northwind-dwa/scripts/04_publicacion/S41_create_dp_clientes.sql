-- =============================================================
-- Script ID : S41
-- Etapa     : 04 - Publicación
-- Descripción: Crea el Producto de Datos DP02_CLIENTES.
--              Perfil completo del cliente: métricas de compra,
--              segmento, enriquecimiento geográfico y socioeconómico.
-- Fecha      : 2026-06-06
-- =============================================================

INSERT INTO DQM_LOG_EJECUCION (script_id, script_nombre, fecha_inicio, resultado)
VALUES ('S41', 'S41_create_dp_clientes.sql', datetime('now'), 'RUNNING');

-- ── DP02: Perfil de cliente ───────────────────────────────────
DROP TABLE IF EXISTS DP02_CLIENTES;

CREATE TABLE DP02_CLIENTES AS
SELECT
    -- Identificación
    c.customer_id,
    c.company_name,
    c.contact_name,
    c.city          AS cliente_ciudad,
    c.region        AS cliente_region,
    c.country       AS cliente_pais,
    -- Segmentación y score
    c.score,
    c.segmento,
    -- Enriquecimiento geográfico
    c.pais_region_mundo,
    c.pais_pib,
    g.capital       AS pais_capital,
    g.poblacion     AS pais_poblacion,
    -- Métricas de comportamiento de compra
    COUNT(DISTINCT f.order_id)              AS total_pedidos,
    SUM(f.quantity)                         AS total_unidades,
    ROUND(SUM(f.monto_bruto), 2)            AS ingreso_bruto_total,
    ROUND(SUM(f.monto_neto),  2)            AS ingreso_neto_total,
    ROUND(AVG(f.monto_neto),  2)            AS ticket_promedio_neto,
    ROUND(AVG(f.discount) * 100, 2)         AS descuento_prom_pct,
    ROUND(SUM(f.freight), 2)                AS flete_total,
    COUNT(DISTINCT f.product_id)            AS productos_distintos,
    COUNT(DISTINCT p.category_name)         AS categorias_distintas,
    -- Temporalidad
    MIN(t.fecha)                            AS primera_compra,
    MAX(t.fecha)                            AS ultima_compra,
    MAX(t.anio)                             AS ultimo_anio_compra,
    -- Estado
    c.activo
FROM DWA_DIM_CLIENTE c
LEFT JOIN DWA_FACT_VENTAS  f ON c.customer_id  = f.customer_id
LEFT JOIN DWA_DIM_TIEMPO   t ON f.fecha_id      = t.fecha_id
LEFT JOIN DWA_DIM_PRODUCTO p ON f.product_id    = p.product_id
LEFT JOIN DWA_DIM_GEOGRAFIA g ON LOWER(TRIM(c.country)) = LOWER(TRIM(g.country))
                              AND g.city IS NULL
GROUP BY
    c.customer_id, c.company_name, c.contact_name,
    c.city, c.region, c.country,
    c.score, c.segmento,
    c.pais_region_mundo, c.pais_pib,
    g.capital, g.poblacion,
    c.activo;

-- Registrar en DQM
INSERT INTO DQM_TRANSFORMACION (ingesta_id, origen, destino, tipo, registros_afect, fecha)
VALUES (2, 'DWA_DIM_CLIENTE + DWA_FACT_VENTAS + DWA_DIM_GEOGRAFIA', 'DP02_CLIENTES', 'INSERT',
        (SELECT COUNT(*) FROM DP02_CLIENTES), datetime('now'));

UPDATE DQM_LOG_EJECUCION
SET fecha_fin = datetime('now'), resultado = 'OK',
    mensaje = 'DP02_CLIENTES creado con ' || (SELECT COUNT(*) FROM DP02_CLIENTES) || ' filas',
    registros_proc = (SELECT COUNT(*) FROM DP02_CLIENTES)
WHERE script_id = 'S41' AND resultado = 'RUNNING';

-- Preview: top clientes por ingreso neto
SELECT customer_id, company_name, segmento,
       total_pedidos, ingreso_neto_total, descuento_prom_pct
FROM DP02_CLIENTES
ORDER BY ingreso_neto_total DESC
LIMIT 10;
