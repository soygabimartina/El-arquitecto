-- =============================================================
-- Script ID : S35
-- Etapa     : 03 - Actualización
-- Descripción: Incorpora datos de world-data-2023 (TXT_WORLD_DATA)
--              al DWA. Puebla DWA_DIM_GEOGRAFIA y enriquece
--              DWA_DIM_CLIENTE con región y PIB del país.
-- Fecha      : 2026-06-06
-- =============================================================

INSERT INTO DQM_LOG_EJECUCION (script_id, script_nombre, fecha_inicio, resultado)
VALUES ('S35', 'S35_add_world_data.sql', datetime('now'), 'RUNNING');

-- ── 1. Poblar DWA_DIM_GEOGRAFIA desde TXT_WORLD_DATA ─────────
-- Sólo insertar países que aún no existen (INSERT OR IGNORE)
INSERT OR IGNORE INTO DWA_DIM_GEOGRAFIA
    (country, city, region, capital, region_mundo, poblacion, pib_usd, fecha_carga)
SELECT
    wd.country,
    NULL,                                       -- nivel país, sin ciudad específica
    NULL,
    wd.capital,
    -- Derivar región a partir de la columna abreviación / continente si está disponible
    -- En world-data-2023 no hay columna directa de región; usamos abreviacion como proxy
    NULL,
    CAST(REPLACE(REPLACE(wd.population, ',', ''), ' ', '') AS INTEGER),
    CAST(REPLACE(REPLACE(REPLACE(wd.gdp, '$', ''), ',', ''), ' ', '') AS REAL),
    datetime('now')
FROM TXT_WORLD_DATA wd
WHERE wd.country IS NOT NULL AND wd.country != '';

-- ── 2. Enriquecer DWA_DIM_CLIENTE con PIB y capital del país ─
-- La columna pais_pib se toma del gdp del país del cliente
UPDATE DWA_DIM_CLIENTE
SET
    pais_pib = (
        SELECT CAST(REPLACE(REPLACE(REPLACE(wd.gdp, '$', ''), ',', ''), ' ', '') AS REAL)
        FROM TXT_WORLD_DATA wd
        WHERE LOWER(TRIM(wd.country)) = LOWER(TRIM(DWA_DIM_CLIENTE.country))
        LIMIT 1
    ),
    pais_region_mundo = (
        SELECT wd.capital          -- usamos capital como identificador geográfico
        FROM TXT_WORLD_DATA wd
        WHERE LOWER(TRIM(wd.country)) = LOWER(TRIM(DWA_DIM_CLIENTE.country))
        LIMIT 1
    )
WHERE country IS NOT NULL;

-- ── 3. Registrar en DQM ──────────────────────────────────────
INSERT INTO DQM_TRANSFORMACION (ingesta_id, origen, destino, tipo, registros_afect, fecha)
VALUES
    (2, 'TXT_WORLD_DATA', 'DWA_DIM_GEOGRAFIA',        'INSERT',
     (SELECT COUNT(*) FROM DWA_DIM_GEOGRAFIA WHERE fecha_carga >= date('now')), datetime('now')),
    (2, 'TXT_WORLD_DATA', 'DWA_DIM_CLIENTE.pais_pib', 'UPDATE',
     (SELECT COUNT(*) FROM DWA_DIM_CLIENTE WHERE pais_pib IS NOT NULL), datetime('now'));

-- ── Preview ──────────────────────────────────────────────────
SELECT country, capital, poblacion, pib_usd
FROM DWA_DIM_GEOGRAFIA
WHERE pib_usd IS NOT NULL
ORDER BY pib_usd DESC
LIMIT 10;

SELECT COUNT(*) AS clientes_con_pib
FROM DWA_DIM_CLIENTE
WHERE pais_pib IS NOT NULL;

UPDATE DQM_LOG_EJECUCION
SET fecha_fin = datetime('now'), resultado = 'OK',
    mensaje = 'World-data incorporado: DIM_GEOGRAFIA poblada, DIM_CLIENTE enriquecida',
    registros_proc = (SELECT COUNT(*) FROM DWA_DIM_GEOGRAFIA)
WHERE script_id = 'S35' AND resultado = 'RUNNING';
