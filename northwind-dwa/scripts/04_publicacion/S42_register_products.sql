-- =============================================================
-- Script ID : S42
-- Etapa     : 04 - Publicación
-- Descripción: Registra los Productos de Datos en DQM y Metadata.
--              Genera resumen final de la ejecución completa del
--              pipeline.
-- Fecha      : 2026-06-06
-- =============================================================

INSERT INTO DQM_LOG_EJECUCION (script_id, script_nombre, fecha_inicio, resultado)
VALUES ('S42', 'S42_register_products.sql', datetime('now'), 'RUNNING');

-- ── Registrar DP01_VENTAS en DQM_TRANSFORMACION ──────────────
INSERT OR IGNORE INTO DQM_TRANSFORMACION (ingesta_id, origen, destino, tipo, registros_afect, fecha)
SELECT 2, 'DWA_FACT_VENTAS + DWA_DIM_*', 'DP01_VENTAS', 'INSERT',
       (SELECT COUNT(*) FROM DP01_VENTAS), datetime('now')
WHERE NOT EXISTS (
    SELECT 1 FROM DQM_TRANSFORMACION WHERE destino = 'DP01_VENTAS'
);

-- ── Asegurar registro de DP02_CLIENTES ───────────────────────
INSERT OR IGNORE INTO DQM_TRANSFORMACION (ingesta_id, origen, destino, tipo, registros_afect, fecha)
SELECT 2, 'DWA_DIM_CLIENTE + DWA_FACT_VENTAS', 'DP02_CLIENTES', 'INSERT',
       (SELECT COUNT(*) FROM DP02_CLIENTES), datetime('now')
WHERE NOT EXISTS (
    SELECT 1 FROM DQM_TRANSFORMACION WHERE destino = 'DP02_CLIENTES'
);

-- ── Registrar DPs en MET_ENTIDAD (si no existen) ─────────────
INSERT OR IGNORE INTO MET_ENTIDAD
    (nombre, capa, tipo, descripcion, fuente, script_creacion, fecha_creacion)
VALUES
    ('DP01_VENTAS',   'DP', 'MART',
     'Ventas mensuales por producto, cliente y empleado',
     'DWA_FACT_VENTAS + DWA_DIM_*', 'S40', datetime('now')),
    ('DP02_CLIENTES', 'DP', 'MART',
     'Perfil cliente con métricas de compra y enriquecimiento geográfico',
     'DWA_DIM_CLIENTE + DWA_FACT_VENTAS + DWA_DIM_GEOGRAFIA', 'S41', datetime('now'));

-- ── Resumen final de calidad del pipeline ─────────────────────
SELECT
    'CALIDAD TOTAL' AS metrica,
    COUNT(*)        AS total_controles,
    SUM(CASE WHEN decision = 'ACEPTADO'  THEN 1 ELSE 0 END) AS aceptados,
    SUM(CASE WHEN decision = 'RECHAZADO' THEN 1 ELSE 0 END) AS rechazados,
    ROUND(AVG(pct_calidad), 2)  AS pct_calidad_promedio
FROM DQM_CONTROL_CAMPO;

-- ── Resumen de scripts ejecutados ────────────────────────────
SELECT resultado, COUNT(*) AS cantidad
FROM DQM_LOG_EJECUCION
GROUP BY resultado;

-- ── Resumen de tablas publicadas ──────────────────────────────
SELECT
    'DP01_VENTAS'  AS producto,
    COUNT(*)       AS filas,
    SUM(monto_neto_total) AS ingreso_neto_total
FROM DP01_VENTAS
UNION ALL
SELECT
    'DP02_CLIENTES',
    COUNT(*),
    SUM(ingreso_neto_total)
FROM DP02_CLIENTES;

-- ── Estado de enriquecimiento ────────────────────────────────
SELECT * FROM VW_ENRIQUECIMIENTO_STATUS;

-- ── Estado de alertas DQM ────────────────────────────────────
SELECT nivel, tipo, COUNT(*) AS cantidad
FROM DQM_ALERTA
GROUP BY nivel, tipo
ORDER BY nivel DESC, tipo;

UPDATE DQM_LOG_EJECUCION
SET fecha_fin = datetime('now'), resultado = 'OK',
    mensaje = 'Pipeline completo. Productos publicados: DP01_VENTAS, DP02_CLIENTES',
    registros_proc = (SELECT COUNT(*) FROM DP01_VENTAS) +
                     (SELECT COUNT(*) FROM DP02_CLIENTES)
WHERE script_id = 'S42' AND resultado = 'RUNNING';
