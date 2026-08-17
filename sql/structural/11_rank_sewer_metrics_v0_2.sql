-- Ranks each v0.2 sewer metric independently. Rankings remain candidates;
-- this script does not create the five-metric composite or a freeze.

CREATE OR REPLACE TABLE
  `devjam26aug17tpe-1270.subterrat_predictions.sewer_metric_rankings_v0_2_candidate`
CLUSTER BY variant_id, cell_id AS
WITH
base AS (
  SELECT *
  FROM `devjam26aug17tpe-1270.subterrat_features.sewer_metrics_v0_2_candidate`
),
metric_rows AS (
  SELECT
    grid_version,
    parent_feature_snapshot_id,
    source_snapshot_id,
    cell_id,
    cell_token,
    eligible_area_m2,
    metric.variant_id,
    metric.raw_value,
    metric.direction,
    metric.metric_gate_state
  FROM base
  CROSS JOIN UNNEST([
    STRUCT(
      'sewer_system_type' AS variant_id,
      sanitary_system_record_share AS raw_value,
      'HIGHER' AS direction,
      'PASS_REUSED_V0_1_COMPONENT' AS metric_gate_state
    ),
    STRUCT(
      'surface_elevation' AS variant_id,
      surface_elevation_m AS raw_value,
      'HIGHER' AS direction,
      'CONDITIONAL_FIELD_SEMANTICS_AND_COVERAGE_REVIEW' AS metric_gate_state
    ),
    STRUCT(
      'connected_pipe_diameter' AS variant_id,
      connected_pipe_diameter_m AS raw_value,
      'LOWER' AS direction,
      'CONDITIONAL_GEOMETRY_AND_COVERAGE_REVIEW' AS metric_gate_state
    ),
    STRUCT(
      'connected_pipe_depth' AS variant_id,
      connected_pipe_depth_m AS raw_value,
      'LOWER' AS direction,
      'BLOCKED_AUTHORITY_BACKED_OUTLIER_RULE_REQUIRED' AS metric_gate_state
    ),
    STRUCT(
      'connected_pipe_age' AS variant_id,
      connected_pipe_age_years AS raw_value,
      'HIGHER' AS direction,
      'BLOCKED_INSTALL_DATE_CONCENTRATION_REVIEW' AS metric_gate_state
    )
  ]) AS metric
),
rankable AS (
  SELECT *
  FROM metric_rows
  WHERE raw_value IS NOT NULL
),
ranked AS (
  SELECT
    *,
    CASE direction
      WHEN 'HIGHER' THEN PERCENT_RANK() OVER (
        PARTITION BY variant_id ORDER BY raw_value
      )
      WHEN 'LOWER' THEN PERCENT_RANK() OVER (
        PARTITION BY variant_id ORDER BY raw_value DESC
      )
    END AS diagnostic_percentile
  FROM rankable
),
all_rows AS (
  SELECT
    metric_rows.* EXCEPT(raw_value),
    ranked.raw_value,
    ranked.diagnostic_percentile
  FROM metric_rows
  LEFT JOIN ranked
    ON metric_rows.variant_id = ranked.variant_id
    AND metric_rows.cell_id = ranked.cell_id
),
area_ranked AS (
  SELECT
    *,
    SUM(IF(diagnostic_percentile IS NULL, 0, eligible_area_m2)) OVER (
      PARTITION BY variant_id
      ORDER BY diagnostic_percentile DESC NULLS LAST, cell_id
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_scored_area_m2,
    SUM(eligible_area_m2) OVER (PARTITION BY variant_id)
      AS total_city_area_m2
  FROM all_rows
),
thresholds AS (
  SELECT
    variant_id,
    MIN(diagnostic_percentile) AS diagnostic_threshold_score
  FROM area_ranked
  WHERE
    diagnostic_percentile IS NOT NULL
    AND cumulative_scored_area_m2 - eligible_area_m2 < total_city_area_m2 * 0.10
  GROUP BY variant_id
)
SELECT
  grid_version,
  parent_feature_snapshot_id,
  source_snapshot_id,
  variant_id,
  cell_id,
  cell_token,
  eligible_area_m2,
  raw_value,
  direction,
  diagnostic_percentile,
  IF(
    metric_gate_state LIKE 'PASS_%',
    diagnostic_percentile,
    NULL
  ) AS metric_score,
  diagnostic_percentile IS NOT NULL
    AND diagnostic_percentile >= thresholds.diagnostic_threshold_score
    AS diagnostic_top_10pct_area_flag,
  metric_gate_state LIKE 'PASS_%'
    AND diagnostic_percentile IS NOT NULL
    AND diagnostic_percentile >= thresholds.diagnostic_threshold_score
    AS candidate_top_10pct_area_flag,
  thresholds.diagnostic_threshold_score,
  'INCLUDE_ALL_THRESHOLD_TIES' AS selection_tie_policy,
  metric_gate_state,
  'OUTCOME_FREE_NOT_FROZEN' AS evidence_state,
  'BLOCKED_METRICS_HAVE_DIAGNOSTIC_PERCENTILE_NOT_MODEL_SCORE'
    AS score_semantics,
  'sewer_metric_candidates_v0_2' AS score_version
FROM area_ranked
LEFT JOIN thresholds USING (variant_id);

ASSERT (
  SELECT
    COUNT(*) = 3420 * 5
    AND COUNT(*) = COUNT(DISTINCT CONCAT(variant_id, ':', CAST(cell_id AS STRING)))
    AND COUNT(DISTINCT variant_id) = 5
    AND COUNTIF(evidence_state != 'OUTCOME_FREE_NOT_FROZEN') = 0
    AND COUNTIF(
      score_semantics != 'BLOCKED_METRICS_HAVE_DIAGNOSTIC_PERCENTILE_NOT_MODEL_SCORE'
    ) = 0
    AND COUNTIF(metric_gate_state NOT LIKE 'PASS_%' AND metric_score IS NOT NULL) = 0
  FROM `devjam26aug17tpe-1270.subterrat_predictions.sewer_metric_rankings_v0_2_candidate`
) AS 'sewer v0.2 metric ranking identity or semantics are invalid';
