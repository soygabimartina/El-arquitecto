-- =============================================================
-- Script ID : S31
-- Etapa     : 03 - Actualización
-- Descripción: Controles de calidad sobre los datos de Ingesta2:
--              TXT_WORLD_DATA, TXT_CUSTOMER_SCORE y las nuevas
--              filas de TXT_ORDERS.
-- Fecha      : 2026-06-06
-- =============================================================

INSERT INTO DQM_LOG_EJECUCION (script_id, script_nombre, fecha_inicio, resultado)
VALUES ('S31', 'S31_validate_ingesta2.sql', datetime('now'), 'RUNNING');

-- ══════════════════════════════════════════════════════════════
-- TXT_WORLD_DATA: validaciones
-- ══════════════════════════════════════════════════════════════

-- ── UNICIDAD: country ─────────────────────────────────────────
INSERT INTO DQM_CONTROL_CAMPO
    (ingesta_id, tabla, campo, tipo_control, total_registros,
     registros_ok, registros_error, pct_calidad, umbral_minimo, decision, fecha)
SELECT 2, 'TXT_WORLD_DATA', 'country', 'UNICIDAD',
    COUNT(*),
    COUNT(DISTINCT country),
    COUNT(*) - COUNT(DISTINCT country),
    ROUND(100.0 * COUNT(DISTINCT country) / MAX(COUNT(*),1), 2),
    99.0,
    CASE WHEN COUNT(*) = COUNT(DISTINCT country) THEN 'ACEPTADO' ELSE 'RECHAZADO' END,
    datetime('now')
FROM TXT_WORLD_DATA WHERE country IS NOT NULL;

-- ── TIPO: gdp debe ser numérico ───────────────────────────────
INSERT INTO DQM_CONTROL_CAMPO
    (ingesta_id, tabla, campo, tipo_control, total_registros,
     registros_ok, registros_error, pct_calidad, umbral_minimo, decision, fecha)
SELECT 2, 'TXT_WORLD_DATA', 'gdp', 'TIPO',
    COUNT(*),
    SUM(CASE WHEN gdp IS NULL OR CAST(gdp AS REAL) IS NOT NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN gdp IS NOT NULL AND CAST(gdp AS REAL) IS NULL THEN 1 ELSE 0 END),
    ROUND(100.0 * SUM(CASE WHEN gdp IS NULL OR CAST(gdp AS REAL) IS NOT NULL THEN 1 ELSE 0 END) / MAX(COUNT(*),1), 2),
    90.0,
    CASE WHEN ROUND(100.0 * SUM(CASE WHEN gdp IS NULL OR CAST(gdp AS REAL) IS NOT NULL THEN 1 ELSE 0 END) / MAX(COUNT(*),1), 2) >= 90
         THEN 'ACEPTADO' ELSE 'RECHAZADO' END,
    datetime('now')
FROM TXT_WORLD_DATA;

-- ── NULOS: population ────────────────────────────────────────
INSERT INTO DQM_CONTROL_CAMPO
    (ingesta_id, tabla, campo, tipo_control, total_registros,
     registros_ok, registros_error, pct_calidad, umbral_minimo, decision, fecha)
SELECT 2, 'TXT_WORLD_DATA', 'population', 'NULOS',
    COUNT(*),
    SUM(CASE WHEN population IS NOT NULL AND population != '' THEN 1 ELSE 0 END),
    SUM(CASE WHEN population IS NULL OR population = '' THEN 1 ELSE 0 END),
    ROUND(100.0 * SUM(CASE WHEN population IS NOT NULL AND population != '' THEN 1 ELSE 0 END) / MAX(COUNT(*),1), 2),
    90.0,
    CASE WHEN ROUND(100.0 * SUM(CASE WHEN population IS NOT NULL AND population != '' THEN 1 ELSE 0 END) / MAX(COUNT(*),1), 2) >= 90
         THEN 'ACEPTADO' ELSE 'RECHAZADO' END,
    datetime('now')
FROM TXT_WORLD_DATA;

-- ══════════════════════════════════════════════════════════════
-- TXT_CUSTOMER_SCORE: validaciones
-- ══════════════════════════════════════════════════════════════

-- ── UNICIDAD: customer_id ─────────────────────────────────────
INSERT INTO DQM_CONTROL_CAMPO
    (ingesta_id, tabla, campo, tipo_control, total_registros,
     registros_ok, registros_error, pct_calidad, umbral_minimo, decision, fecha)
SELECT 2, 'TXT_CUSTOMER_SCORE', 'customer_id', 'UNICIDAD',
    COUNT(*),
    COUNT(DISTINCT customer_id),
    COUNT(*) - COUNT(DISTINCT customer_id),
    ROUND(100.0 * COUNT(DISTINCT customer_id) / MAX(COUNT(*),1), 2),
    100.0,
    CASE WHEN COUNT(*) = COUNT(DISTINCT customer_id) THEN 'ACEPTADO' ELSE 'RECHAZADO' END,
    datetime('now')
FROM TXT_CUSTOMER_SCORE WHERE customer_id IS NOT NULL;

-- ── TIPO: score debe ser numérico ─────────────────────────────
INSERT INTO DQM_CONTROL_CAMPO
    (ingesta_id, tabla, campo, tipo_control, total_registros,
     registros_ok, registros_error, pct_calidad, umbral_minimo, decision, fecha)
SELECT 2, 'TXT_CUSTOMER_SCORE', 'score', 'TIPO',
    COUNT(*),
    SUM(CASE WHEN score IS NULL OR CAST(score AS REAL) IS NOT NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN score IS NOT NULL AND CAST(score AS REAL) IS NULL THEN 1 ELSE 0 END),
    ROUND(100.0 * SUM(CASE WHEN score IS NULL OR CAST(score AS REAL) IS NOT NULL THEN 1 ELSE 0 END) / MAX(COUNT(*),1), 2),
    99.0,
    CASE WHEN ROUND(100.0 * SUM(CASE WHEN score IS NULL OR CAST(score AS REAL) IS NOT NULL THEN 1 ELSE 0 END) / MAX(COUNT(*),1), 2) >= 99
         THEN 'ACEPTADO' ELSE 'RECHAZADO' END,
    datetime('now')
FROM TXT_CUSTOMER_SCORE;

-- ── RANGO: score entre 0 y 100 ───────────────────────────────
INSERT INTO DQM_CONTROL_CAMPO
    (ingesta_id, tabla, campo, tipo_control, total_registros,
     registros_ok, registros_error, pct_calidad, umbral_minimo, decision, fecha)
SELECT 2, 'TXT_CUSTOMER_SCORE', 'score', 'RANGO',
    COUNT(*),
    SUM(CASE WHEN CAST(score AS REAL) BETWEEN 0 AND 100 THEN 1 ELSE 0 END),
    SUM(CASE WHEN CAST(score AS REAL) NOT BETWEEN 0 AND 100 THEN 1 ELSE 0 END),
    ROUND(100.0 * SUM(CASE WHEN CAST(score AS REAL) BETWEEN 0 AND 100 THEN 1 ELSE 0 END) / MAX(COUNT(*),1), 2),
    100.0,
    CASE WHEN ROUND(100.0 * SUM(CASE WHEN CAST(score AS REAL) BETWEEN 0 AND 100 THEN 1 ELSE 0 END) / MAX(COUNT(*),1), 2) >= 100
         THEN 'ACEPTADO' ELSE 'RECHAZADO' END,
    datetime('now')
FROM TXT_CUSTOMER_SCORE WHERE score IS NOT NULL AND CAST(score AS REAL) IS NOT NULL;

-- ── RI: customer_id de score debe existir en TMP_CUSTOMERS ───
INSERT INTO DQM_CONTROL_CAMPO
    (ingesta_id, tabla, campo, tipo_control, total_registros,
     registros_ok, registros_error, pct_calidad, umbral_minimo, decision, fecha)
SELECT 2, 'TXT_CUSTOMER_SCORE', 'customer_id', 'RI',
    COUNT(*),
    SUM(CASE WHEN c.customer_id IS NOT NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN c.customer_id IS NULL THEN 1 ELSE 0 END),
    ROUND(100.0 * SUM(CASE WHEN c.customer_id IS NOT NULL THEN 1 ELSE 0 END) / MAX(COUNT(*),1), 2),
    95.0,
    CASE WHEN ROUND(100.0 * SUM(CASE WHEN c.customer_id IS NOT NULL THEN 1 ELSE 0 END) / MAX(COUNT(*),1), 2) >= 95
         THEN 'ACEPTADO' ELSE 'RECHAZADO' END,
    datetime('now')
FROM TXT_CUSTOMER_SCORE sc
LEFT JOIN TMP_CUSTOMERS c ON sc.customer_id = c.customer_id;

-- ══════════════════════════════════════════════════════════════
-- Resumen de controles Ingesta2
-- ══════════════════════════════════════════════════════════════
SELECT tabla, campo, tipo_control, registros_error, pct_calidad, decision
FROM DQM_CONTROL_CAMPO
WHERE ingesta_id = 2
ORDER BY decision DESC, pct_calidad ASC;

-- Poblar resumen global
INSERT INTO DQM_RESUMEN_CALIDAD (ingesta_id, total_controles, controles_ok, controles_rechazados, pct_calidad_global, fecha)
SELECT
    2,
    COUNT(*),
    SUM(CASE WHEN decision = 'ACEPTADO'  THEN 1 ELSE 0 END),
    SUM(CASE WHEN decision = 'RECHAZADO' THEN 1 ELSE 0 END),
    ROUND(AVG(pct_calidad), 2),
    datetime('now')
FROM DQM_CONTROL_CAMPO WHERE ingesta_id = 2;

UPDATE DQM_LOG_EJECUCION
SET fecha_fin = datetime('now'), resultado = 'OK',
    mensaje = 'Validación Ingesta2 completada. Ver DQM_CONTROL_CAMPO ingesta_id=2',
    registros_proc = (SELECT COUNT(*) FROM DQM_CONTROL_CAMPO WHERE ingesta_id = 2)
WHERE script_id = 'S31' AND resultado = 'RUNNING';
