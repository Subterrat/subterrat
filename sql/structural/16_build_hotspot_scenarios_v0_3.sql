-- Materializes the outcome-blinded v0.3 internal simulation only from a clean,
-- committed specification. Running this file before the artifact identity is
-- fixed is intentionally impossible.
--
-- Required named query parameters:
--   specification_git_head STRING (40 lowercase hexadecimal characters)
--   repository_state STRING (must be COMMITTED_SOURCE)
--   review_verdict STRING (must be REVISE_BEFORE_SIMULATION)
--   review_receipt_sha256 STRING
--   scenario_contract_sha256 STRING
--   scenario_sql_sha256 STRING
--   urban_renewal_source_snapshot_id STRING

ASSERT (
  REGEXP_CONTAINS(@specification_git_head, r'^[0-9a-f]{40}$')
  AND @repository_state = 'COMMITTED_SOURCE'
  AND @review_verdict = 'REVISE_BEFORE_SIMULATION'
  AND REGEXP_CONTAINS(@review_receipt_sha256, r'^[0-9a-f]{64}$')
  AND REGEXP_CONTAINS(@scenario_contract_sha256, r'^[0-9a-f]{64}$')
  AND REGEXP_CONTAINS(@scenario_sql_sha256, r'^[0-9a-f]{64}$')
  AND @urban_renewal_source_snapshot_id =
    'f31369ef4f27e6028db450051550e52f45b43f3f4e8f723ae9c50ac4ff0b1f6e'
) AS 'v0.3 internal-simulation artifact identity is incomplete or invalid';

CREATE OR REPLACE TABLE
  `devjam26aug17tpe-1270.subterrat_predictions.hotspot_scenarios_v0_3_internal_simulation`
CLUSTER BY variant_id, cell_id AS
WITH
cells AS (
  SELECT
    grid_version,
    cell_id,
    cell_token,
    eligible_area_m2
  FROM `devjam26aug17tpe-1270.subterrat_curated.analysis_cells`
),
v0_1 AS (
  SELECT
    cell_id,
    food_score,
    sewer_score AS sewer_system_type_score
  FROM `devjam26aug17tpe-1270.subterrat_predictions.map_hotspot_cells_t0`
),
sewer_metric_pivot AS (
  SELECT
    cell_id,
    MAX(IF(variant_id = 'sewer_system_type', diagnostic_percentile, NULL))
      AS sewer_system_type,
    MAX(IF(variant_id = 'surface_elevation', diagnostic_percentile, NULL))
      AS surface_elevation,
    MAX(IF(variant_id = 'connected_pipe_diameter', diagnostic_percentile, NULL))
      AS connected_pipe_diameter,
    MAX(IF(variant_id = 'connected_pipe_depth', diagnostic_percentile, NULL))
      AS connected_pipe_depth,
    MAX(IF(variant_id = 'connected_pipe_age', diagnostic_percentile, NULL))
      AS connected_pipe_age,
    COUNTIF(diagnostic_percentile IS NOT NULL) AS available_metric_count
  FROM
    `devjam26aug17tpe-1270.subterrat_predictions.sewer_metric_rankings_v0_2_candidate`
  GROUP BY cell_id
),
sewer_composite AS (
  SELECT
    cell_id,
    IF(
      available_metric_count = 5,
      (
        sewer_system_type
        + surface_elevation
        + connected_pipe_diameter
        + connected_pipe_depth
        + connected_pipe_age
      ) / 5,
      NULL
    ) AS sewer_attribute_index
  FROM sewer_metric_pivot
),
renewal AS (
  SELECT
    cell_id,
    MAX(IF(
      analysis_window_m = 0,
      admin_site_empirical_percentile,
      NULL
    )) AS approved_rebuilding_admin_site_r0,
    MAX(IF(
      analysis_window_m = 150,
      admin_site_empirical_percentile,
      NULL
    )) AS approved_rebuilding_admin_site_r150,
    MAX(IF(
      analysis_window_m = 300,
      admin_site_empirical_percentile,
      NULL
    )) AS approved_rebuilding_admin_site_r300
  FROM
    `devjam26aug17tpe-1270.subterrat_features.urban_renewal_admin_site_metrics_v0_3_internal_simulation`
  GROUP BY cell_id
),
components AS (
  SELECT
    cells.*,
    v0_1.food_score,
    v0_1.sewer_system_type_score,
    sewer_composite.sewer_attribute_index,
    renewal.approved_rebuilding_admin_site_r0,
    renewal.approved_rebuilding_admin_site_r150,
    renewal.approved_rebuilding_admin_site_r300
  FROM cells
  LEFT JOIN v0_1 USING (cell_id)
  LEFT JOIN sewer_composite USING (cell_id)
  LEFT JOIN renewal USING (cell_id)
),
variant_rows AS (
  SELECT
    components.*,
    variant.variant_id,
    variant.simulation_index,
    variant.scenario_state
  FROM components
  CROSS JOIN UNNEST([
    STRUCT(
      'food_market_only_v0_1' AS variant_id,
      food_score AS simulation_index,
      'FROZEN_V0_1_REFERENCE' AS scenario_state
    ),
    STRUCT(
      'sewer_system_type_only_v0_1' AS variant_id,
      sewer_system_type_score AS simulation_index,
      'FROZEN_V0_1_REFERENCE_PARTIAL_COVERAGE' AS scenario_state
    ),
    STRUCT(
      'sewer_attribute_index_v0_2_complete_case' AS variant_id,
      sewer_attribute_index AS simulation_index,
      'BLOCKED_INTERNAL_SIMULATION_V0_2_GATES_INCOMPLETE' AS scenario_state
    ),
    STRUCT(
      'approved_rebuilding_admin_site_cell_footprint_buffer_0m' AS variant_id,
      approved_rebuilding_admin_site_r0 AS simulation_index,
      'BLOCKED_INTERNAL_SIMULATION_SOURCE_GATES_INCOMPLETE' AS scenario_state
    ),
    STRUCT(
      'approved_rebuilding_admin_site_cell_footprint_buffer_150m' AS variant_id,
      approved_rebuilding_admin_site_r150 AS simulation_index,
      'BLOCKED_INTERNAL_SIMULATION_SOURCE_GATES_INCOMPLETE' AS scenario_state
    ),
    STRUCT(
      'approved_rebuilding_admin_site_cell_footprint_buffer_300m' AS variant_id,
      approved_rebuilding_admin_site_r300 AS simulation_index,
      'BLOCKED_INTERNAL_SIMULATION_SOURCE_GATES_INCOMPLETE' AS scenario_state
    ),
    STRUCT(
      'v0_3_equal_group_internal_simulation_r150' AS variant_id,
      IF(
        food_score IS NOT NULL
          AND sewer_attribute_index IS NOT NULL
          AND approved_rebuilding_admin_site_r150 IS NOT NULL,
        (
          food_score
          + sewer_attribute_index
          + approved_rebuilding_admin_site_r150
        ) / 3,
        NULL
      ) AS simulation_index,
      'BLOCKED_INTERNAL_SIMULATION' AS scenario_state
    )
  ]) AS variant
),
area_ranked AS (
  SELECT
    *,
    SUM(IF(simulation_index IS NULL, 0, eligible_area_m2)) OVER (
      PARTITION BY variant_id
      ORDER BY simulation_index DESC NULLS LAST, cell_id
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_scored_area_m2,
    SUM(eligible_area_m2) OVER (PARTITION BY variant_id) AS total_city_area_m2
  FROM variant_rows
),
thresholds AS (
  SELECT
    variant_id,
    MIN(simulation_index) AS threshold_index
  FROM area_ranked
  WHERE
    simulation_index IS NOT NULL
    AND cumulative_scored_area_m2 - eligible_area_m2
      < total_city_area_m2 * 0.10
  GROUP BY variant_id
),
ranked_scores AS (
  SELECT
    variant_id,
    cell_id,
    PERCENT_RANK() OVER (
      PARTITION BY variant_id
      ORDER BY simulation_index
    ) AS rank_within_scoreable_support
  FROM area_ranked
  WHERE simulation_index IS NOT NULL
)
SELECT
  grid_version,
  variant_id,
  cell_id,
  cell_token,
  eligible_area_m2,
  food_score,
  sewer_system_type_score,
  sewer_attribute_index,
  approved_rebuilding_admin_site_r0,
  approved_rebuilding_admin_site_r150,
  approved_rebuilding_admin_site_r300,
  simulation_index,
  ranked_scores.rank_within_scoreable_support,
  simulation_index IS NOT NULL
    AND simulation_index >= thresholds.threshold_index
    AS preregistered_selected_scenario_area_flag,
  thresholds.threshold_index,
  'INCLUDE_ALL_THRESHOLD_TIES' AS selection_tie_policy,
  scenario_state,
  'LOCKED' AS specification_state,
  'INTERNAL_SIMULATION_ONLY' AS use_state,
  'NO_TRUSTED_RESULT' AS evidence_state,
  'PROHIBITED' AS operational_use,
  'ORDINAL_SIMULATION_INDEX_NOT_PROBABILITY' AS score_semantics,
  @specification_git_head AS specification_git_head,
  @repository_state AS specification_source,
  @review_verdict AS review_verdict,
  @review_receipt_sha256 AS review_receipt_sha256,
  @scenario_contract_sha256 AS scenario_contract_sha256,
  @scenario_sql_sha256 AS scenario_sql_sha256,
  @urban_renewal_source_snapshot_id AS urban_renewal_source_snapshot_id,
  'hotspot_scenarios_v0_3_internal_simulation' AS score_version
FROM area_ranked
LEFT JOIN thresholds USING (variant_id)
LEFT JOIN ranked_scores USING (variant_id, cell_id);

ASSERT (
  SELECT
    COUNT(*) = 3420 * 7
    AND COUNT(*) = COUNT(DISTINCT CONCAT(variant_id, ':', CAST(cell_id AS STRING)))
    AND COUNT(DISTINCT variant_id) = 7
    AND COUNTIF(simulation_index NOT BETWEEN 0 AND 1) = 0
    AND COUNTIF(
      variant_id = 'v0_3_equal_group_internal_simulation_r150'
      AND simulation_index IS NOT NULL
      AND (
        food_score IS NULL
        OR sewer_attribute_index IS NULL
        OR approved_rebuilding_admin_site_r150 IS NULL
      )
    ) = 0
    AND COUNTIF(specification_state != 'LOCKED') = 0
    AND COUNTIF(use_state != 'INTERNAL_SIMULATION_ONLY') = 0
    AND COUNTIF(evidence_state != 'NO_TRUSTED_RESULT') = 0
    AND COUNTIF(operational_use != 'PROHIBITED') = 0
    AND COUNTIF(score_semantics != 'ORDINAL_SIMULATION_INDEX_NOT_PROBABILITY') = 0
    AND COUNT(DISTINCT specification_git_head) = 1
    AND COUNT(DISTINCT review_receipt_sha256) = 1
    AND COUNT(DISTINCT scenario_contract_sha256) = 1
    AND COUNT(DISTINCT scenario_sql_sha256) = 1
  FROM
    `devjam26aug17tpe-1270.subterrat_predictions.hotspot_scenarios_v0_3_internal_simulation`
) AS 'v0.3 internal simulation identity, range, or gate state is invalid';
