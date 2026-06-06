-- =============================================================
-- Script ID : S36
-- Etapa     : 03 - Actualización
-- Descripción: Incorpora customer_score (TXT_CUSTOMER_SCORE) a
--              DWA_DIM_CLIENTE. Calcula segmento según score:
--              ALTO (>=70), MEDIO (40-69), BAJO (<40).
-- Fecha      : 2026-06-06
-- =============================================================

INSERT INTO DQM_LOG_EJECUCION (script_id, script_nombre, fecha_inicio, resultado)
VALUES ('S36', 'S36_add_customer_score.sql', datetime('now'), 'RUNNING');

-- ── Actualizar score y segmento en DIM_CLIENTE ───────────────
UPDATE DWA_DIM_CLIENTE
SET
    score = (
        SELECT CAST(TRIM(cs.score) AS REAL)
        FROM TXT_CUSTOMER_SCORE cs
        WHERE cs.customer_id = DWA_DIM_CLIENTE.customer_id
        LIMIT 1
    ),
    segmento = (
        SELECT
            CASE
                WHEN CAST(TRIM(cs.score) AS REAL) >= 70 THEN 'ALTO'
                WHEN CAST(TRIM(cs.score) AS REAL) >= 40 THEN 'MEDIO'
                ELSE 'BAJO'
            END
        FROM TXT_CUSTOMER_SCORE cs
        WHERE cs.customer_id = DWA_DIM_CLIENTE.customer_id
        LIMIT 1
    )
WHERE EXISTS (
    SELECT 1 FROM TXT_CUSTOMER_SCORE cs
    WHERE cs.customer_id = DWA_DIM_CLIENTE.customer_id
);

-- ── Para clientes sin score: asignar segmento 'SIN_DATOS' ────
UPDATE DWA_DIM_CLIENTE
SET segmento = 'SIN_DATOS'
WHERE score IS NULL AND segmento IS NULL;

-- ── Registrar en DQM ──────────────────────────────────────────
INSERT INTO DQM_TRANSFORMACION (ingesta_id, origen, destino, tipo, registros_afect, fecha)
VALUES (2, 'TXT_CUSTOMER_SCORE', 'DWA_DIM_CLIENTE.score + segmento', 'UPDATE',
        (SELECT COUNT(*) FROM DWA_DIM_CLIENTE WHERE score IS NOT NULL), datetime('now'));

-- ── Validar calidad del enriquecimiento ───────────────────────
INSERT INTO DQM_CONTROL_CAMPO
    (ingesta_id, tabla, campo, tipo_control, total_registros,
     registros_ok, registros_error, pct_calidad, umbral_minimo, decision, fecha)
SELECT 2, 'DWA_DIM_CLIENTE', 'score', 'NULOS',
    COUNT(*),
    SUM(CASE WHEN score IS NOT NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN score IS NULL THEN 1 ELSE 0 END),
    ROUND(100.0 * SUM(CASE WHEN score IS NOT NULL THEN 1 ELSE 0 END) / MAX(COUNT(*),1), 2),
    60.0,   -- umbral: al menos 60% de clientes deben tener score
    CASE WHEN ROUND(100.0 * SUM(CASE WHEN score IS NOT NULL THEN 1 ELSE 0 END) / MAX(COUNT(*),1), 2) >= 60
         THEN 'ACEPTADO' ELSE 'RECHAZADO' END,
    datetime('now')
FROM DWA_DIM_CLIENTE;

-- ── Preview de distribución de segmentos ─────────────────────
SELECT segmento, COUNT(*) AS clientes,
       ROUND(AVG(score), 2) AS score_promedio
FROM DWA_DIM_CLIENTE
GROUP BY segmento
ORDER BY segmento;

UPDATE DQM_LOG_EJECUCION
SET fecha_fin = datetime('now'), resultado = 'OK',
    mensaje = 'Customer score incorporado: score y segmento actualizados en DIM_CLIENTE',
    registros_proc = (SELECT COUNT(*) FROM DWA_DIM_CLIENTE WHERE score IS NOT NULL)
WHERE script_id = 'S36' AND resultado = 'RUNNING';
