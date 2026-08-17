-- Summarizes support and tie-aware area selection without reading any report
-- locations or other outcome data.

CREATE OR REPLACE TABLE
  `devjam26aug17tpe-1270.subterrat_predictions.hotspot_scenario_quality_v0_3_internal_simulation` AS
SELECT
  variant_id,
  COUNT(*) AS city_cell_count,
  COUNTIF(simulation_index IS NOT NULL) AS scoreable_cell_count,
  SAFE_DIVIDE(COUNTIF(simulation_index IS NOT NULL), COUNT(*))
    AS scoreable_cell_share,
  SUM(eligible_area_m2) AS total_city_area_m2,
  SUM(IF(simulation_index IS NOT NULL, eligible_area_m2, 0))
    AS scoreable_area_m2,
  SAFE_DIVIDE(
    SUM(IF(simulation_index IS NOT NULL, eligible_area_m2, 0)),
    SUM(eligible_area_m2)
  ) AS scoreable_area_share,
  SUM(IF(preregistered_selected_scenario_area_flag, eligible_area_m2, 0))
    AS selected_area_m2,
  SAFE_DIVIDE(
    SUM(IF(preregistered_selected_scenario_area_flag, eligible_area_m2, 0)),
    SUM(eligible_area_m2)
  ) AS selected_area_share,
  MIN(simulation_index) AS min_simulation_index,
  MAX(simulation_index) AS max_simulation_index,
  ANY_VALUE(threshold_index) AS threshold_index,
  COUNTIF(
    simulation_index IS NOT NULL
    AND simulation_index = threshold_index
  ) AS threshold_tie_cell_count,
  ANY_VALUE(scenario_state) AS scenario_state,
  ANY_VALUE(specification_state) AS specification_state,
  ANY_VALUE(use_state) AS use_state,
  ANY_VALUE(evidence_state) AS evidence_state,
  ANY_VALUE(operational_use) AS operational_use,
  ANY_VALUE(specification_git_head) AS specification_git_head,
  ANY_VALUE(review_receipt_sha256) AS review_receipt_sha256,
  FALSE AS public_release_ready,
  FALSE AS operational_use_ready
FROM
  `devjam26aug17tpe-1270.subterrat_predictions.hotspot_scenarios_v0_3_internal_simulation`
GROUP BY variant_id;

ASSERT (
  SELECT
    COUNT(*) = 7
    AND COUNTIF(city_cell_count != 3420) = 0
    AND COUNTIF(scoreable_area_share < 0 OR scoreable_area_share > 1) = 0
    AND COUNTIF(selected_area_share < 0 OR selected_area_share > 1) = 0
    AND COUNTIF(specification_state != 'LOCKED') = 0
    AND COUNTIF(use_state != 'INTERNAL_SIMULATION_ONLY') = 0
    AND COUNTIF(evidence_state != 'NO_TRUSTED_RESULT') = 0
    AND COUNTIF(operational_use != 'PROHIBITED') = 0
    AND COUNTIF(public_release_ready) = 0
    AND COUNTIF(operational_use_ready) = 0
  FROM
    `devjam26aug17tpe-1270.subterrat_predictions.hotspot_scenario_quality_v0_3_internal_simulation`
) AS 'v0.3 internal-simulation quality summary is invalid';
