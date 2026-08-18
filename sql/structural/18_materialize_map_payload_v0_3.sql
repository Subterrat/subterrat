-- Aggregate-cell payload for the internal React lab. Exact administrative-site
-- locations and all retrospective report rows are intentionally absent.

CREATE OR REPLACE TABLE
  `devjam26aug17tpe-1270.subterrat_predictions.map_hotspot_cells_v0_3_internal_simulation`
CLUSTER BY cell_id AS
WITH
scenario AS (
  SELECT *
  FROM
    `devjam26aug17tpe-1270.subterrat_predictions.hotspot_scenarios_v0_3_internal_simulation`
  WHERE variant_id = 'v0_3_equal_group_internal_simulation_r150'
),
sewer_metrics AS (
  SELECT
    cell_id,
    MAX(IF(variant_id = 'sewer_system_type', diagnostic_percentile, NULL))
      AS sewer_system_type_diagnostic,
    MAX(IF(variant_id = 'surface_elevation', diagnostic_percentile, NULL))
      AS surface_elevation_diagnostic,
    MAX(IF(variant_id = 'connected_pipe_diameter', diagnostic_percentile, NULL))
      AS connected_pipe_diameter_diagnostic,
    MAX(IF(variant_id = 'connected_pipe_depth', diagnostic_percentile, NULL))
      AS connected_pipe_depth_diagnostic,
    MAX(IF(variant_id = 'connected_pipe_age', diagnostic_percentile, NULL))
      AS connected_pipe_age_diagnostic
  FROM
    `devjam26aug17tpe-1270.subterrat_predictions.sewer_metric_rankings_v0_2_candidate`
  GROUP BY cell_id
)
SELECT
  cells.grid_version,
  cells.cell_id,
  cells.cell_token,
  cells.centroid_longitude,
  cells.centroid_latitude,
  ST_ASGEOJSON(cells.eligible_geom) AS eligible_geojson,
  cells.eligible_area_m2,
  scenario.food_score,
  scenario.sewer_system_type_score,
  sewer_metrics.sewer_system_type_diagnostic,
  sewer_metrics.surface_elevation_diagnostic,
  sewer_metrics.connected_pipe_diameter_diagnostic,
  sewer_metrics.connected_pipe_depth_diagnostic,
  sewer_metrics.connected_pipe_age_diagnostic,
  scenario.sewer_attribute_index,
  scenario.approved_rebuilding_admin_site_r0,
  scenario.approved_rebuilding_admin_site_r150,
  scenario.approved_rebuilding_admin_site_r300,
  scenario.simulation_index AS v0_3_simulation_index,
  scenario.rank_within_scoreable_support,
  scenario.preregistered_selected_scenario_area_flag,
  scenario.scenario_state,
  scenario.specification_state,
  scenario.use_state,
  scenario.evidence_state,
  scenario.operational_use,
  scenario.specification_git_head,
  scenario.specification_source,
  scenario.review_verdict,
  scenario.review_receipt_sha256,
  scenario.scenario_contract_sha256,
  scenario.scenario_sql_sha256,
  scenario.urban_renewal_source_snapshot_id,
  [
    'NO_TRUSTED_RESULT',
    'OPERATIONAL_USE_PROHIBITED',
    'V0_2_SEWER_GATES_INCOMPLETE',
    'URBAN_RENEWAL_SOURCE_REUSE_LICENSE_INCOMPLETE',
    'URBAN_RENEWAL_STATUS_TAXONOMY_AND_TEMPORAL_MEANING_INCOMPLETE',
    'URBAN_RENEWAL_SOURCE_RECORD_NUMBER_SEMANTICS_UNDOCUMENTED',
    'URBAN_RENEWAL_ADMIN_SITE_COVERAGE_247_OF_248',
    'ORDINAL_SIMULATION_INDEX_NOT_PROBABILITY'
  ] AS limitation_codes,
  'v0_3_equal_group_internal_simulation_r150' AS scenario_id,
  'SPECIFICATION_LOCKED_INTERNAL_SIMULATION_ONLY' AS release_state,
  'ORDINAL_SIMULATION_INDEX_NOT_PROBABILITY' AS score_semantics,
  CAST(NULL AS FLOAT64) AS calibrated_probability
FROM `devjam26aug17tpe-1270.subterrat_curated.analysis_cells` AS cells
LEFT JOIN scenario USING (cell_id)
LEFT JOIN sewer_metrics USING (cell_id);

ASSERT (
  SELECT
    COUNT(*) = 3420
    AND COUNT(*) = COUNT(DISTINCT cell_id)
    AND COUNTIF(eligible_geojson IS NULL) = 0
    AND COUNTIF(v0_3_simulation_index NOT BETWEEN 0 AND 1) = 0
    AND COUNTIF(calibrated_probability IS NOT NULL) = 0
    AND COUNTIF(specification_state != 'LOCKED') = 0
    AND COUNTIF(use_state != 'INTERNAL_SIMULATION_ONLY') = 0
    AND COUNTIF(evidence_state != 'NO_TRUSTED_RESULT') = 0
    AND COUNTIF(operational_use != 'PROHIBITED') = 0
    AND COUNTIF(score_semantics != 'ORDINAL_SIMULATION_INDEX_NOT_PROBABILITY') = 0
  FROM
    `devjam26aug17tpe-1270.subterrat_predictions.map_hotspot_cells_v0_3_internal_simulation`
) AS 'v0.3 internal map payload identity, geometry, or gate state is invalid';
