-- Online-feature-only benchmark. This script neither reads an outcome table
-- nor creates a fitted model. Each available feature layer is ranked alone.

CREATE SCHEMA IF NOT EXISTS
  `devjam26aug17tpe-1270.subterrat_predictions`
OPTIONS(location = 'asia-east1');

CREATE OR REPLACE TABLE
  `devjam26aug17tpe-1270.subterrat_predictions.layer_scores_t0_candidate`
CLUSTER BY variant_id, cell_id AS
WITH
base AS (
  SELECT *
  FROM `devjam26aug17tpe-1270.subterrat_features.cell_features_t0_candidate`
),
food_ranked AS (
  SELECT
    cell_id,
    food_market_sites_per_km2 AS raw_value,
    PERCENT_RANK() OVER (
      ORDER BY food_market_sites_per_km2
    ) AS layer_score
  FROM base
  WHERE food_market_sites_per_km2 IS NOT NULL
),
sewer_ranked AS (
  SELECT
    cell_id,
    sanitary_system_record_share AS raw_value,
    PERCENT_RANK() OVER (
      ORDER BY sanitary_system_record_share
    ) AS layer_score
  FROM base
  WHERE sanitary_system_record_share IS NOT NULL
),
abandoned_ranked AS (
  SELECT
    cell_id,
    CAST(abandoned_building_count AS FLOAT64) AS raw_value,
    PERCENT_RANK() OVER (
      ORDER BY abandoned_building_count
    ) AS layer_score
  FROM base
  WHERE abandoned_building_count IS NOT NULL
),
layer_rows AS (
  SELECT
    base.feature_snapshot_id,
    base.grid_version,
    'food_market_only' AS variant_id,
    base.cell_id,
    base.cell_token,
    base.eligible_area_m2,
    food_ranked.raw_value,
    food_ranked.layer_score,
    'PROVISIONAL_AVAILABLE' AS candidate_state
  FROM base
  LEFT JOIN food_ranked USING (cell_id)

  UNION ALL

  SELECT
    base.feature_snapshot_id,
    base.grid_version,
    'sewer_system_type_only' AS variant_id,
    base.cell_id,
    base.cell_token,
    base.eligible_area_m2,
    sewer_ranked.raw_value,
    sewer_ranked.layer_score,
    'PROVISIONAL_AVAILABLE_PARTIAL_COVERAGE' AS candidate_state
  FROM base
  LEFT JOIN sewer_ranked USING (cell_id)

  UNION ALL

  SELECT
    base.feature_snapshot_id,
    base.grid_version,
    'abandoned_building_only' AS variant_id,
    base.cell_id,
    base.cell_token,
    base.eligible_area_m2,
    abandoned_ranked.raw_value,
    abandoned_ranked.layer_score,
    'PROVISIONAL_OVERLAY_NOT_RANKED' AS candidate_state
  FROM base
  LEFT JOIN abandoned_ranked USING (cell_id)
),
area_ranked AS (
  SELECT
    *,
    SUM(IF(layer_score IS NULL, 0, eligible_area_m2)) OVER (
      PARTITION BY variant_id
      ORDER BY layer_score DESC NULLS LAST, cell_id
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_scored_area_m2,
    SUM(eligible_area_m2) OVER (PARTITION BY variant_id) AS total_city_area_m2
  FROM layer_rows
),
thresholds AS (
  SELECT
    variant_id,
    MIN(layer_score) AS selection_threshold_score
  FROM area_ranked
  WHERE
    layer_score IS NOT NULL
    AND cumulative_scored_area_m2 - eligible_area_m2 < total_city_area_m2 * 0.10
  GROUP BY variant_id
)
SELECT
  feature_snapshot_id,
  grid_version,
  variant_id,
  cell_id,
  cell_token,
  eligible_area_m2,
  raw_value,
  layer_score,
  layer_score IS NOT NULL
    AND layer_score >= thresholds.selection_threshold_score
    AS top_10pct_area_flag,
  thresholds.selection_threshold_score,
  'INCLUDE_ALL_THRESHOLD_TIES' AS selection_tie_policy,
  candidate_state,
  'PROVISIONAL_ONLINE_DATA_BENCHMARK' AS evidence_state,
  'LAYER_SCORE_NOT_PROBABILITY' AS score_semantics,
  'layerwise_online_v0_1' AS score_version
FROM area_ranked
LEFT JOIN thresholds USING (variant_id);

ASSERT (
  SELECT COUNT(*) = COUNT(DISTINCT CONCAT(variant_id, ':', CAST(cell_id AS STRING)))
  FROM `devjam26aug17tpe-1270.subterrat_predictions.layer_scores_t0_candidate`
) AS 'layer score variant_id/cell_id must be unique';

ASSERT (
  SELECT COUNTIF(variant_id = 'food_market_only' AND layer_score IS NOT NULL) > 0
  FROM `devjam26aug17tpe-1270.subterrat_predictions.layer_scores_t0_candidate`
) AS 'food layer must have scored cells';

ASSERT (
  SELECT COUNTIF(variant_id = 'sewer_system_type_only' AND layer_score IS NOT NULL) > 0
  FROM `devjam26aug17tpe-1270.subterrat_predictions.layer_scores_t0_candidate`
) AS 'sewer system-type layer must have scored cells';

ASSERT (
  SELECT COUNTIF(variant_id = 'abandoned_building_only' AND layer_score IS NOT NULL) = 0
  FROM `devjam26aug17tpe-1270.subterrat_predictions.layer_scores_t0_candidate`
) AS 'unused-building overlay must not be promoted into a ranked citywide feature';
