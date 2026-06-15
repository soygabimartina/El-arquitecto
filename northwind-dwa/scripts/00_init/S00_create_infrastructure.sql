-- =============================================================
-- Script ID : S00
-- Etapa     : 00 - Inicialización
-- Descripción: Crea la infraestructura base: LOG, Inventario de
--              scripts y tablas DQM fundamentales.
-- Fecha      : 2026-06-06
-- =============================================================

-- ── LOG de ejecución de scripts ──────────────────────────────
CREATE TABLE IF NOT EXISTS DQM_LOG_EJECUCION (
    log_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    script_id       TEXT    NOT NULL,
    script_nombre   TEXT    NOT NULL,
    fecha_inicio    TEXT    NOT NULL,
    fecha_fin       TEXT,
    resultado       TEXT    CHECK(resultado IN ('OK','ERROR','WARNING')),
    mensaje         TEXT,
    registros_proc  INTEGER DEFAULT 0
);

-- ── Inventario de scripts ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS DQM_INVENTARIO_SCRIPTS (
    script_id       TEXT    PRIMARY KEY,
    script_nombre   TEXT    NOT NULL,
    etapa           TEXT    NOT NULL,
    descripcion     TEXT,
    fecha_creacion  TEXT,
    autor           TEXT
);

-- ── Controles de calidad por campo ───────────────────────────
CREATE TABLE IF NOT EXISTS DQM_CONTROL_CAMPO (
    control_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    ingesta_id      INTEGER NOT NULL,
    tabla           TEXT    NOT NULL,
    campo           TEXT    NOT NULL,
    tipo_control    TEXT    NOT NULL,  -- NULOS | TIPO | RANGO | UNICIDAD | RI
    total_registros INTEGER DEFAULT 0,
    registros_ok    INTEGER DEFAULT 0,
    registros_error INTEGER DEFAULT 0,
    pct_calidad     REAL,
    umbral_minimo   REAL,
    decision        TEXT    CHECK(decision IN ('ACEPTADO','RECHAZADO','PARCIAL')),
    fecha           TEXT    NOT NULL
);

-- ── Perfilado de tablas ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS DQM_PERFILADO (
    perfil_id       INTEGER PRIMARY KEY AUTOINCREMENT,
    ingesta_id      INTEGER NOT NULL,
    tabla           TEXT    NOT NULL,
    total_filas     INTEGER DEFAULT 0,
    total_columnas  INTEGER DEFAULT 0,
    nulos_total     INTEGER DEFAULT 0,
    duplicados_pk   INTEGER DEFAULT 0,
    fecha           TEXT    NOT NULL
);

-- ── Huella de transformaciones ────────────────────────────────
CREATE TABLE IF NOT EXISTS DQM_TRANSFORMACION (
    transf_id       INTEGER PRIMARY KEY AUTOINCREMENT,
    ingesta_id      INTEGER NOT NULL,
    origen          TEXT    NOT NULL,
    destino         TEXT    NOT NULL,
    tipo            TEXT    CHECK(tipo IN ('COPIA','INSERT','UPDATE','DELETE')),
    registros_afect INTEGER DEFAULT 0,
    fecha           TEXT    NOT NULL
);

-- ── Registro de ingesta ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS DQM_INGESTA (
    ingesta_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre          TEXT    NOT NULL,  -- 'INGESTA1' | 'INGESTA2'
    fecha_inicio    TEXT    NOT NULL,
    fecha_fin       TEXT,
    resultado       TEXT,
    total_tablas    INTEGER DEFAULT 0,
    observaciones   TEXT
);

-- Log de creación de este script
INSERT INTO DQM_LOG_EJECUCION (script_id, script_nombre, fecha_inicio, fecha_fin, resultado, mensaje, registros_proc)
VALUES ('S00', 'S00_create_infrastructure.sql', datetime('now'), datetime('now'), 'OK',
        'Infraestructura DQM creada correctamente', 5);
