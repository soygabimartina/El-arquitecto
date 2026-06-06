-- =============================================================
-- Script ID : S20
-- Etapa     : 02 - Ingeniería
-- Descripción: Crea la capa de Metadatos (MET_). Documenta
--              entidades, atributos y procesos ETL del DWA.
-- Fecha      : 2026-06-06
-- =============================================================

INSERT INTO DQM_LOG_EJECUCION (script_id, script_nombre, fecha_inicio, resultado)
VALUES ('S20', 'S20_create_metadata.sql', datetime('now'), 'RUNNING');

-- ── MET_ENTIDAD: catálogo de tablas y vistas ──────────────────
CREATE TABLE IF NOT EXISTS MET_ENTIDAD (
    entidad_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre          TEXT    NOT NULL UNIQUE,
    capa            TEXT    NOT NULL, -- TXT|TMP|DWA|DWM|DQM|MET|DP
    tipo            TEXT    NOT NULL, -- TABLA|VISTA|MART
    descripcion     TEXT,
    fuente          TEXT,             -- origen de los datos
    script_creacion TEXT,
    fecha_creacion  TEXT    NOT NULL
);

-- ── MET_ATRIBUTO: catálogo de campos ─────────────────────────
CREATE TABLE IF NOT EXISTS MET_ATRIBUTO (
    atributo_id        INTEGER PRIMARY KEY AUTOINCREMENT,
    entidad_nombre     TEXT    NOT NULL,
    atributo_nombre    TEXT    NOT NULL,
    tipo_dato          TEXT    NOT NULL,
    es_pk              INTEGER DEFAULT 0,
    es_fk              INTEGER DEFAULT 0,
    nullable           INTEGER DEFAULT 1,
    tabla_referenciada TEXT,
    descripcion        TEXT,
    regla_negocio      TEXT
);

-- ── MET_PROCESO: catálogo de procesos ETL ────────────────────
CREATE TABLE IF NOT EXISTS MET_PROCESO (
    proceso_id       INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre           TEXT    NOT NULL,
    etapa            TEXT    NOT NULL,
    script_origen    TEXT,
    descripcion      TEXT,
    frecuencia       TEXT,   -- UNICA|BATCH|INCREMENTAL
    ultima_ejecucion TEXT
);

-- ── MET_LINAJE: linaje de datos (origen → destino) ────────────
CREATE TABLE IF NOT EXISTS MET_LINAJE (
    linaje_id       INTEGER PRIMARY KEY AUTOINCREMENT,
    entidad_origen  TEXT    NOT NULL,
    entidad_destino TEXT    NOT NULL,
    campo_origen    TEXT,
    campo_destino   TEXT,
    transformacion  TEXT,
    script_id       TEXT,
    fecha           TEXT    NOT NULL
);

UPDATE DQM_LOG_EJECUCION
SET fecha_fin = datetime('now'), resultado = 'OK',
    mensaje = 'Capa de metadatos creada: MET_ENTIDAD, MET_ATRIBUTO, MET_PROCESO, MET_LINAJE',
    registros_proc = 4
WHERE script_id = 'S20' AND resultado = 'RUNNING';
