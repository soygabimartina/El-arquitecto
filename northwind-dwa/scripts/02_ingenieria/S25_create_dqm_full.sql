-- =============================================================
-- Script ID : S25
-- Etapa     : 02 - Ingeniería
-- Descripción: Crea tablas DQM adicionales para alertas y
--              resúmenes de calidad por ingesta.
-- Fecha      : 2026-06-06
-- =============================================================

INSERT INTO DQM_LOG_EJECUCION (script_id, script_nombre, fecha_inicio, resultado)
VALUES ('S25', 'S25_create_dqm_full.sql', datetime('now'), 'RUNNING');

-- ── DQM_ALERTA: alertas de calidad ───────────────────────────
CREATE TABLE IF NOT EXISTS DQM_ALERTA (
    alerta_id   INTEGER PRIMARY KEY AUTOINCREMENT,
    ingesta_id  INTEGER NOT NULL,
    tipo        TEXT    NOT NULL CHECK(tipo IN ('CALIDAD','REFERENCIAL','VOLUMEN','SISTEMA')),
    nivel       TEXT    NOT NULL CHECK(nivel IN ('ERROR','WARNING','INFO')),
    tabla       TEXT,
    campo       TEXT,
    mensaje     TEXT    NOT NULL,
    valor_obs   TEXT,
    fecha       TEXT    NOT NULL
);

-- ── DQM_RESUMEN_CALIDAD: resumen por ingesta ──────────────────
CREATE TABLE IF NOT EXISTS DQM_RESUMEN_CALIDAD (
    resumen_id            INTEGER PRIMARY KEY AUTOINCREMENT,
    ingesta_id            INTEGER NOT NULL,
    total_controles       INTEGER DEFAULT 0,
    controles_ok          INTEGER DEFAULT 0,
    controles_rechazados  INTEGER DEFAULT 0,
    pct_calidad_global    REAL,
    fecha                 TEXT    NOT NULL
);

-- ── DQM_UMBRAL_GLOBAL: umbrales globales configurables ────────
CREATE TABLE IF NOT EXISTS DQM_UMBRAL_GLOBAL (
    umbral_id   INTEGER PRIMARY KEY AUTOINCREMENT,
    tipo_control TEXT   NOT NULL,  -- NULOS|TIPO|RANGO|UNICIDAD|RI
    capa        TEXT    NOT NULL,  -- TXT|TMP|DWA
    umbral_pct  REAL    NOT NULL,
    descripcion TEXT
);

-- Poblar umbrales globales de referencia
INSERT OR IGNORE INTO DQM_UMBRAL_GLOBAL (tipo_control, capa, umbral_pct, descripcion) VALUES
('NULOS',    'TMP', 95.0, 'Máx. 5% nulos en campos obligatorios de TMP_'),
('TIPO',     'TXT', 95.0, 'Máx. 5% errores de tipo en TXT_ antes de conversión'),
('RANGO',    'TMP', 98.0, 'Máx. 2% fuera de rango en TMP_'),
('UNICIDAD', 'TXT',100.0, 'Cero duplicados de PK permitidos'),
('RI',       'TMP', 95.0, 'Umbral general integridad referencial'),
('RI',       'DWA', 99.0, 'Umbral RI en tablas críticas del DWA');

-- ── Vista resumen de calidad por ingesta ─────────────────────
DROP VIEW IF EXISTS VW_DQM_RESUMEN;
CREATE VIEW VW_DQM_RESUMEN AS
SELECT
    ingesta_id,
    tipo_control,
    COUNT(*)                                    AS total_controles,
    SUM(CASE WHEN decision = 'ACEPTADO' THEN 1 ELSE 0 END) AS aceptados,
    SUM(CASE WHEN decision = 'RECHAZADO' THEN 1 ELSE 0 END) AS rechazados,
    ROUND(AVG(pct_calidad), 2)                  AS pct_calidad_promedio,
    MIN(pct_calidad)                            AS pct_calidad_min
FROM DQM_CONTROL_CAMPO
GROUP BY ingesta_id, tipo_control
ORDER BY ingesta_id, tipo_control;

-- ── Poblar alertas a partir de controles ya ejecutados ───────
INSERT INTO DQM_ALERTA (ingesta_id, tipo, nivel, tabla, campo, mensaje, valor_obs, fecha)
SELECT
    ingesta_id,
    CASE tipo_control WHEN 'RI' THEN 'REFERENCIAL' ELSE 'CALIDAD' END,
    CASE WHEN pct_calidad < umbral_minimo THEN 'ERROR' ELSE 'INFO' END,
    tabla,
    campo,
    'Control ' || tipo_control || ': ' || decision || ' (' || pct_calidad || '% vs umbral ' || umbral_minimo || '%)',
    CAST(registros_error AS TEXT),
    fecha
FROM DQM_CONTROL_CAMPO
WHERE decision = 'RECHAZADO';

UPDATE DQM_LOG_EJECUCION
SET fecha_fin = datetime('now'), resultado = 'OK',
    mensaje = 'DQM extendido: DQM_ALERTA, DQM_RESUMEN_CALIDAD, DQM_UMBRAL_GLOBAL, VW_DQM_RESUMEN',
    registros_proc = 4
WHERE script_id = 'S25' AND resultado = 'RUNNING';

-- Preview de alertas activas
SELECT nivel, COUNT(*) AS cantidad FROM DQM_ALERTA GROUP BY nivel ORDER BY nivel;
