-- =============================================================
-- Script ID : S33
-- Etapa     : 03 - Actualización
-- Descripción: Registra en DWM_ (capa de Memoria) la historia
--              de los campos modificados (SCD Tipo 2).
--              Ejecutar ANTES de S32 para capturar valores previos.
-- Fecha      : 2026-06-06
-- =============================================================

INSERT INTO DQM_LOG_EJECUCION (script_id, script_nombre, fecha_inicio, resultado)
VALUES ('S33', 'S33_update_memory.sql', datetime('now'), 'RUNNING');

-- ── Crear tablas DWM si no existen ────────────────────────────
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

-- ── Detectar y registrar cambios en CLIENTES ─────────────────
-- company_name
INSERT INTO DWM_CLIENTE_HIST
    (customer_id, campo_modificado, valor_anterior, valor_nuevo, fecha_desde, ingesta_id)
SELECT
    d.customer_id,
    'company_name',
    d.company_name,
    t.company_name,
    datetime('now'),
    2
FROM DWA_DIM_CLIENTE d
JOIN TMP_CUSTOMERS t ON d.customer_id = t.customer_id
WHERE COALESCE(d.company_name,'') != COALESCE(t.company_name,'');

-- city
INSERT INTO DWM_CLIENTE_HIST
    (customer_id, campo_modificado, valor_anterior, valor_nuevo, fecha_desde, ingesta_id)
SELECT d.customer_id, 'city', d.city, t.city, datetime('now'), 2
FROM DWA_DIM_CLIENTE d
JOIN TMP_CUSTOMERS t ON d.customer_id = t.customer_id
WHERE COALESCE(d.city,'') != COALESCE(t.city,'');

-- country
INSERT INTO DWM_CLIENTE_HIST
    (customer_id, campo_modificado, valor_anterior, valor_nuevo, fecha_desde, ingesta_id)
SELECT d.customer_id, 'country', d.country, t.country, datetime('now'), 2
FROM DWA_DIM_CLIENTE d
JOIN TMP_CUSTOMERS t ON d.customer_id = t.customer_id
WHERE COALESCE(d.country,'') != COALESCE(t.country,'');

-- ── Detectar y registrar cambios en PRODUCTOS ────────────────
-- unit_price
INSERT INTO DWM_PRODUCTO_HIST
    (product_id, campo_modificado, valor_anterior, valor_nuevo, fecha_desde, ingesta_id)
SELECT d.product_id, 'unit_price', CAST(d.unit_price AS TEXT), CAST(t.unit_price AS TEXT), datetime('now'), 2
FROM DWA_DIM_PRODUCTO d
JOIN TMP_PRODUCTS t ON d.product_id = t.product_id
WHERE d.unit_price != t.unit_price;

-- discontinued
INSERT INTO DWM_PRODUCTO_HIST
    (product_id, campo_modificado, valor_anterior, valor_nuevo, fecha_desde, ingesta_id)
SELECT d.product_id, 'discontinued', CAST(d.discontinued AS TEXT), CAST(t.discontinued AS TEXT), datetime('now'), 2
FROM DWA_DIM_PRODUCTO d
JOIN TMP_PRODUCTS t ON d.product_id = t.product_id
WHERE d.discontinued != t.discontinued;

-- Resumen de cambios detectados
SELECT 'DWM_CLIENTE_HIST' AS tabla, COUNT(*) AS cambios FROM DWM_CLIENTE_HIST WHERE ingesta_id = 2
UNION ALL
SELECT 'DWM_PRODUCTO_HIST', COUNT(*) FROM DWM_PRODUCTO_HIST WHERE ingesta_id = 2;

UPDATE DQM_LOG_EJECUCION
SET fecha_fin = datetime('now'), resultado = 'OK',
    mensaje = 'Historia de cambios registrada en DWM_',
    registros_proc = (SELECT COUNT(*) FROM DWM_CLIENTE_HIST WHERE ingesta_id = 2) +
                     (SELECT COUNT(*) FROM DWM_PRODUCTO_HIST WHERE ingesta_id = 2)
WHERE script_id = 'S33' AND resultado = 'RUNNING';
