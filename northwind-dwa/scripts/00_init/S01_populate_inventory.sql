-- =============================================================
-- Script ID : S01
-- Etapa     : 00 - Inicialización
-- Descripción: Registra todos los scripts del proyecto en el
--              inventario DQM_INVENTARIO_SCRIPTS.
-- Fecha      : 2026-06-06
-- =============================================================

INSERT OR REPLACE INTO DQM_INVENTARIO_SCRIPTS VALUES
-- Etapa 0
('S00','S00_create_infrastructure.sql',       '00-Init',        'Crea LOG, Inventario y DQM base',                          '2026-06-06', 'Equipo'),
('S01','S01_populate_inventory.sql',           '00-Init',        'Registra todos los scripts en el inventario',              '2026-06-06', 'Equipo'),
-- Etapa 1
('S10','S10_create_txt_tables.sql',            '01-Adquisicion', 'Crea tablas TXT_ (todo TEXT)',                             '2026-06-06', 'Equipo'),
('S11','S11_create_tmp_tables.sql',            '01-Adquisicion', 'Crea tablas TMP_ (tipos + PK)',                            '2026-06-06', 'Equipo'),
('S12','S12_validate_txt_format.sql',          '01-Adquisicion', 'Valida formato campo a campo en TXT_',                    '2026-06-06', 'Equipo'),
('S13','S13_validate_pk.sql',                  '01-Adquisicion', 'Valida unicidad de PK antes de mover a TMP_',             '2026-06-06', 'Equipo'),
('S14','S14_profiling.sql',                    '01-Adquisicion', 'Perfilado: nulos, distintos, min/max por tabla',           '2026-06-06', 'Equipo'),
('S15','S15_txt_to_tmp.sql',                   '01-Adquisicion', 'Copia TXT_ → TMP_ si validación aprobada',                '2026-06-06', 'Equipo'),
('S16','S16_validate_referential.sql',         '01-Adquisicion', 'Valida integridad referencial en TMP_',                   '2026-06-06', 'Equipo'),
-- Etapa 2
('S20','S20_create_metadata.sql',              '02-Ingenieria',  'Crea tablas MET_',                                        '2026-06-06', 'Equipo'),
('S21','S21_populate_metadata.sql',            '02-Ingenieria',  'Documenta todas las entidades en MET_',                   '2026-06-06', 'Equipo'),
('S22','S22_create_dwa_model.sql',             '02-Ingenieria',  'Crea modelo dimensional DWA_ (estrella)',                 '2026-06-06', 'Equipo'),
('S23','S23_create_dwm_memory.sql',            '02-Ingenieria',  'Crea tablas DWM_ para SCD tipo 2',                       '2026-06-06', 'Equipo'),
('S24','S24_create_enrichment.sql',            '02-Ingenieria',  'Agrega campos derivados (enriquecimiento)',               '2026-06-06', 'Equipo'),
('S25','S25_create_dqm_full.sql',              '02-Ingenieria',  'Crea tablas DQM adicionales',                             '2026-06-06', 'Equipo'),
('S26','S26_initial_load.sql',                 '02-Ingenieria',  'Carga inicial TMP_ → DWA_',                              '2026-06-06', 'Equipo'),
-- Etapa 3
('S30','S30_load_ingesta2_txt.sql',            '03-Actualizacion','Carga Ingesta2 en TXT_',                                 '2026-06-06', 'Equipo'),
('S31','S31_validate_ingesta2.sql',            '03-Actualizacion','Controles de calidad sobre Ingesta2',                    '2026-06-06', 'Equipo'),
('S32','S32_update_dwa.sql',                   '03-Actualizacion','Actualiza DWA: altas, bajas, modificaciones',            '2026-06-06', 'Equipo'),
('S33','S33_update_memory.sql',                '03-Actualizacion','Registra historia de cambios en DWM_',                   '2026-06-06', 'Equipo'),
('S34','S34_update_enrichment.sql',            '03-Actualizacion','Recalcula datos derivados en DWA_',                      '2026-06-06', 'Equipo'),
('S35','S35_add_world_data.sql',               '03-Actualizacion','Incorpora world-data-2023 al DWA',                       '2026-06-06', 'Equipo'),
('S36','S36_add_customer_score.sql',           '03-Actualizacion','Incorpora customer_score al DWA',                        '2026-06-06', 'Equipo'),
-- Etapa 4
('S40','S40_create_dp_ventas.sql',             '04-Publicacion', 'Crea Producto de Datos DP01_VENTAS',                      '2026-06-06', 'Equipo'),
('S41','S41_create_dp_clientes.sql',           '04-Publicacion', 'Crea Producto de Datos DP02_CLIENTES',                   '2026-06-06', 'Equipo'),
('S42','S42_register_products.sql',            '04-Publicacion', 'Registra DPs en DQM y Metadata',                         '2026-06-06', 'Equipo');

INSERT INTO DQM_LOG_EJECUCION (script_id, script_nombre, fecha_inicio, fecha_fin, resultado, mensaje, registros_proc)
VALUES ('S01', 'S01_populate_inventory.sql', datetime('now'), datetime('now'), 'OK',
        'Inventario de scripts cargado', 26);
