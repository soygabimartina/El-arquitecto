-- =============================================================
-- Script ID : S23
-- Etapa     : 02 - Ingeniería
-- Descripción: Crea las tablas de la capa Memoria (DWM_) para
--              implementar SCD Tipo 2. Se crea antes de la carga
--              inicial para que S33 solo inserte registros.
-- Fecha      : 2026-06-06
-- =============================================================

INSERT INTO DQM_LOG_EJECUCION (script_id, script_nombre, fecha_inicio, resultado)
VALUES ('S23', 'S23_create_dwm_memory.sql', datetime('now'), 'RUNNING');

-- ── Historia de cambios en Clientes ───────────────────────────
-- Campos monitoreados: company_name, city, country
CREATE TABLE IF NOT EXISTS DWM_CLIENTE_HIST (
    hist_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    customer_id      TEXT    NOT NULL,
    campo_modificado TEXT    NOT NULL,
    valor_anterior   TEXT,
    valor_nuevo      TEXT,
    fecha_desde      TEXT    NOT NULL,
    fecha_hasta      TEXT,
    ingesta_id       INTEGER NOT NULL
);

-- ── Historia de cambios en Productos ──────────────────────────
-- Campos monitoreados: unit_price, discontinued
CREATE TABLE IF NOT EXISTS DWM_PRODUCTO_HIST (
    hist_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id       INTEGER NOT NULL,
    campo_modificado TEXT    NOT NULL,
    valor_anterior   TEXT,
    valor_nuevo      TEXT,
    fecha_desde      TEXT    NOT NULL,
    fecha_hasta      TEXT,
    ingesta_id       INTEGER NOT NULL
);

-- ── Índices para consulta eficiente ───────────────────────────
CREATE INDEX IF NOT EXISTS idx_dwm_cli_id   ON DWM_CLIENTE_HIST(customer_id);
CREATE INDEX IF NOT EXISTS idx_dwm_prod_id  ON DWM_PRODUCTO_HIST(product_id);

UPDATE DQM_LOG_EJECUCION
SET fecha_fin = datetime('now'), resultado = 'OK',
    mensaje = 'Tablas DWM_ creadas: DWM_CLIENTE_HIST, DWM_PRODUCTO_HIST',
    registros_proc = 2
WHERE script_id = 'S23' AND resultado = 'RUNNING';
