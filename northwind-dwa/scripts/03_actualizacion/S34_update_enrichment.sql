-- =============================================================
-- Script ID : S34
-- Etapa     : 03 - Actualización
-- Descripción: Recalcula campos derivados en DWA_ tras la carga
--              de Ingesta2. Repara monto_bruto/neto nulos,
--              recalcula dias_entrega y dias_demora para órdenes
--              nuevas o con shipped_date actualizado.
-- Fecha      : 2026-06-06
-- =============================================================

INSERT INTO DQM_LOG_EJECUCION (script_id, script_nombre, fecha_inicio, resultado)
VALUES ('S34', 'S34_update_enrichment.sql', datetime('now'), 'RUNNING');

-- ── Reparar monto_bruto / monto_neto en FACT_VENTAS ──────────
-- Aplica a cualquier fila donde sean NULL (por errores previos)
UPDATE DWA_FACT_VENTAS
SET monto_bruto = ROUND(unit_price * quantity, 2)
WHERE monto_bruto IS NULL;

UPDATE DWA_FACT_VENTAS
SET monto_neto = ROUND(monto_bruto * (1.0 - discount), 2)
WHERE monto_neto IS NULL;

-- ── Recalcular dias_entrega y dias_demora en DIM_ORDEN ───────
-- Sólo para órdenes de Ingesta2 o con shipped_date previamente nulo
UPDATE DWA_DIM_ORDEN
SET dias_entrega = CAST(
        JULIANDAY(
            (SELECT o.shipped_date FROM TMP_ORDERS o WHERE o.order_id = DWA_DIM_ORDEN.order_id)
        ) -
        JULIANDAY(
            (SELECT o.order_date FROM TMP_ORDERS o WHERE o.order_id = DWA_DIM_ORDEN.order_id)
        ) AS INTEGER)
WHERE dias_entrega IS NULL
  AND EXISTS (
        SELECT 1 FROM TMP_ORDERS o
        WHERE o.order_id = DWA_DIM_ORDEN.order_id
          AND o.shipped_date IS NOT NULL AND o.order_date IS NOT NULL
      );

UPDATE DWA_DIM_ORDEN
SET dias_demora = CAST(
        JULIANDAY(
            (SELECT o.shipped_date FROM TMP_ORDERS o WHERE o.order_id = DWA_DIM_ORDEN.order_id)
        ) -
        JULIANDAY(
            (SELECT o.required_date FROM TMP_ORDERS o WHERE o.order_id = DWA_DIM_ORDEN.order_id)
        ) AS INTEGER)
WHERE dias_demora IS NULL
  AND EXISTS (
        SELECT 1 FROM TMP_ORDERS o
        WHERE o.order_id = DWA_DIM_ORDEN.order_id
          AND o.shipped_date IS NOT NULL AND o.required_date IS NOT NULL
      );

-- ── Refresco de la vista de enriquecimiento ──────────────────
-- (las vistas SQLite se refrescan automáticamente, este SELECT
--  sirve para auditar el estado del enriquecimiento)
SELECT * FROM VW_ENRIQUECIMIENTO_STATUS;

-- ── Registrar transformaciones ────────────────────────────────
INSERT INTO DQM_TRANSFORMACION (ingesta_id, origen, destino, tipo, registros_afect, fecha)
VALUES
    (2, 'DWA_FACT_VENTAS (recalculo)', 'DWA_FACT_VENTAS.monto_bruto', 'UPDATE',
     (SELECT COUNT(*) FROM DWA_FACT_VENTAS WHERE monto_bruto IS NOT NULL), datetime('now')),
    (2, 'TMP_ORDERS (dias)', 'DWA_DIM_ORDEN.dias_entrega', 'UPDATE',
     (SELECT COUNT(*) FROM DWA_DIM_ORDEN WHERE dias_entrega IS NOT NULL), datetime('now'));

UPDATE DQM_LOG_EJECUCION
SET fecha_fin = datetime('now'), resultado = 'OK',
    mensaje = 'Enriquecimiento recalculado: monto_bruto/neto, dias_entrega/demora',
    registros_proc = (SELECT COUNT(*) FROM DWA_FACT_VENTAS)
WHERE script_id = 'S34' AND resultado = 'RUNNING';
