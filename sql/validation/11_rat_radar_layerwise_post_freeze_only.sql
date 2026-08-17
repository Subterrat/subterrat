-- VALIDATION ONLY. The layer scores must be copied into a reviewed frozen
-- table before any Rat Radar outcome is materialized or read by this script.

ASSERT (
  SELECT COUNTIF(freeze_status = 'T0_LAYERWISE_FROZEN_AWAITING_VALIDATION') = 1
  FROM `devjam26aug17tpe-1270.subterrat_predictions.freeze_manifest`
) AS 'Rat Radar layer validation is forbidden before T0 layer freeze';

CREATE OR REPLACE TABLE
  `devjam26aug17tpe-1270.subterrat_evaluation.rat_radar_layer_capture_t1` AS
WITH frozen AS (
  SELECT
    variant_id,
    cell_id,
    top_10pct_area_flag,
    eligible_area_m2
  FROM `devjam26aug17tpe-1270.subterrat_predictions.layer_scores_t0`
),
outcome AS (
  SELECT report_id, cell_id
  FROM `devjam26aug17tpe-1270.subterrat_t1_vault.approved_rat_reports_t1`
  WHERE inclusion_status = 'INCLUDED'
),
variant_area AS (
  SELECT
    variant_id,
    SAFE_DIVIDE(
      SUM(IF(top_10pct_area_flag, eligible_area_m2, 0)),
      SUM(eligible_area_m2)
    ) AS selected_area_share
  FROM frozen
  GROUP BY variant_id
),
totals AS (
  SELECT COUNT(DISTINCT report_id) AS denominator
  FROM outcome
),
captured AS (
  SELECT
    frozen.variant_id,
    COUNT(DISTINCT IF(
      frozen.top_10pct_area_flag,
      outcome.report_id,
      NULL
    )) AS numerator
  FROM frozen
  LEFT JOIN outcome USING (cell_id)
  GROUP BY frozen.variant_id
)
SELECT
  captured.variant_id,
  totals.denominator,
  captured.numerator,
  variant_area.selected_area_share,
  SAFE_DIVIDE(captured.numerator, totals.denominator) AS capture_at_10pct,
  SAFE_DIVIDE(
    SAFE_DIVIDE(captured.numerator, totals.denominator),
    variant_area.selected_area_share
  ) AS lift_over_area,
  'VALIDATION_ONLY_NOT_TRAINING' AS outcome_role
FROM captured
JOIN variant_area USING (variant_id)
CROSS JOIN totals;
