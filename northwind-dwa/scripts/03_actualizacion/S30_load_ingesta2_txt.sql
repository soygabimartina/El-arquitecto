-- =============================================================
-- Script ID : S30
-- Etapa     : 03 - Actualización
-- Descripción: Registra el inicio de Ingesta2 en DQM y verifica
--              que las tablas TXT_ de Ingesta2 fueron cargadas
--              por el loader Python (load_csv.py --ingesta 2).
--
-- PREREQUISITO: Ejecutar antes de este script:
--   cd northwind-dwa/loaders
--   python load_csv.py --ingesta 2 --db ../db/northwind_dwa.db --append
--
-- Fecha      : 2026-06-06
-- =============================================================

INSERT INTO DQM_LOG_EJECUCION (script_id, script_nombre, fecha_inicio, resultado)
VALUES ('S30', 'S30_load_ingesta2_txt.sql', datetime('now'), 'RUNNING');

-- ── Registrar ingesta en DQM ──────────────────────────────────
INSERT OR IGNORE INTO DQM_INGESTA (ingesta_id, nombre, fecha_inicio, resultado, total_tablas, observaciones)
VALUES (2, 'INGESTA2', datetime('now'), 'RUNNING', 3,
        'Actualización: orders_update + world-data-2023 + customer_score');

-- ── Verificar volumen de TXT_ cargadas ───────────────────────
-- TXT_ORDERS debe tener filas (ingesta1 + nuevos de ingesta2 --append)
-- TXT_WORLD_DATA debe tener ~195 países
-- TXT_CUSTOMER_SCORE debe tener datos de clientes

-- Insertar control de volumen por tabla
INSERT INTO DQM_CONTROL_CAMPO
    (ingesta_id, tabla, campo, tipo_control, total_registros,
     registros_ok, registros_error, pct_calidad, umbral_minimo, decision, fecha)
SELECT 2, 'TXT_WORLD_DATA', 'country', 'NULOS',
    COUNT(*),
    SUM(CASE WHEN country IS NOT NULL AND country != '' THEN 1 ELSE 0 END),
    SUM(CASE WHEN country IS NULL OR country = '' THEN 1 ELSE 0 END),
    ROUND(100.0 * SUM(CASE WHEN country IS NOT NULL AND country != '' THEN 1 ELSE 0 END) / MAX(COUNT(*),1), 2),
    99.0,
    CASE WHEN COUNT(*) > 0 AND
              ROUND(100.0 * SUM(CASE WHEN country IS NOT NULL AND country != '' THEN 1 ELSE 0 END) / COUNT(*), 2) >= 99
         THEN 'ACEPTADO' ELSE 'RECHAZADO' END,
    datetime('now')
FROM TXT_WORLD_DATA;

INSERT INTO DQM_CONTROL_CAMPO
    (ingesta_id, tabla, campo, tipo_control, total_registros,
     registros_ok, registros_error, pct_calidad, umbral_minimo, decision, fecha)
SELECT 2, 'TXT_CUSTOMER_SCORE', 'customer_id', 'NULOS',
    COUNT(*),
    SUM(CASE WHEN customer_id IS NOT NULL AND customer_id != '' THEN 1 ELSE 0 END),
    SUM(CASE WHEN customer_id IS NULL OR customer_id = '' THEN 1 ELSE 0 END),
    ROUND(100.0 * SUM(CASE WHEN customer_id IS NOT NULL AND customer_id != '' THEN 1 ELSE 0 END) / MAX(COUNT(*),1), 2),
    100.0,
    CASE WHEN COUNT(*) > 0 AND
              ROUND(100.0 * SUM(CASE WHEN customer_id IS NOT NULL AND customer_id != '' THEN 1 ELSE 0 END) / COUNT(*), 2) >= 100
         THEN 'ACEPTADO' ELSE 'RECHAZADO' END,
    datetime('now')
FROM TXT_CUSTOMER_SCORE;

-- ── Conteos de verificación ───────────────────────────────────
SELECT 'TXT_WORLD_DATA'    AS tabla, COUNT(*) AS filas FROM TXT_WORLD_DATA
UNION ALL
SELECT 'TXT_CUSTOMER_SCORE',          COUNT(*) FROM TXT_CUSTOMER_SCORE
UNION ALL
SELECT 'TXT_ORDERS (total c/ingesta1)', COUNT(*) FROM TXT_ORDERS;

-- ── Actualizar DQM_INGESTA ────────────────────────────────────
UPDATE DQM_INGESTA
SET resultado = 'OK', fecha_fin = datetime('now'),
    observaciones = 'TXT_ de ingesta2 verificadas. Continuar con S31.'
WHERE ingesta_id = 2;

UPDATE DQM_LOG_EJECUCION
SET fecha_fin = datetime('now'), resultado = 'OK',
    mensaje = 'Ingesta2 registrada en DQM. TXT_ verificadas.',
    registros_proc = (SELECT COUNT(*) FROM TXT_WORLD_DATA) +
                     (SELECT COUNT(*) FROM TXT_CUSTOMER_SCORE)
WHERE script_id = 'S30' AND resultado = 'RUNNING';
