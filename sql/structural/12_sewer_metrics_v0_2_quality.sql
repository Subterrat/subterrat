-- Persists outcome-free source and metric QA. `composite_allowed_now` remains
-- false until every metric passes its contract gate on the same scope.

CREATE OR REPLACE TABLE
  `devjam26aug17tpe-1270.subterrat_curated.sanitary_pipe_v0_2_quality_candidate` AS
SELECT
  source_snapshot_id,
  COUNT(*) AS segment_rows,
  COUNT(DISTINCT segment_id) AS unique_segment_ids,
  COUNTIF(geom_wgs84 IS NULL) AS invalid_geometry_rows,
  COUNTIF(NOT is_active) AS inactive_rows,
  COUNTIF(is_surveyed) AS surveyed_rows,
  COUNTIF(NOT is_surveyed) AS redrawn_or_other_rows,
  COUNTIF(circular_diameter_m IS NULL) AS invalid_or_non_circular_diameter_rows,
  APPROX_QUANTILES(circular_diameter_m, 100)[OFFSET(50)]
    AS circular_diameter_median_m,
  APPROX_QUANTILES(circular_diameter_m, 100)[OFFSET(99)]
    AS circular_diameter_p99_m,
  APPROX_QUANTILES(mean_cover_depth_m, 100)[OFFSET(50)]
    AS mean_cover_depth_median_m,
  APPROX_QUANTILES(mean_cover_depth_m, 100)[OFFSET(99)]
    AS mean_cover_depth_p99_m,
  MAX(mean_cover_depth_m) AS mean_cover_depth_max_m,
  COUNTIF(install_date IS NULL) AS missing_or_invalid_install_date_rows,
  COUNTIF(install_date > source_snapshot_date) AS future_install_date_rows,
  COUNTIF('REPORTED_LENGTH_DIFF_OVER_10PCT' IN UNNEST(quality_flags))
    AS reported_length_difference_over_10pct_rows,
  FALSE AS model_feature_ready,
  'AUTHORITY_STATUS_DEPTH_DATE_GEOMETRY_AND_COVERAGE_GATES_REQUIRED'
    AS readiness_note
FROM `devjam26aug17tpe-1270.subterrat_curated.sanitary_pipe_segment_v0_2_candidate`
GROUP BY source_snapshot_id;

CREATE OR REPLACE TABLE
  `devjam26aug17tpe-1270.subterrat_predictions.sewer_metric_quality_v0_2_candidate` AS
SELECT
  variant_id,
  ANY_VALUE(parent_feature_snapshot_id) AS parent_feature_snapshot_id,
  ANY_VALUE(source_snapshot_id) AS source_snapshot_id,
  COUNT(*) AS total_city_cells,
  COUNTIF(diagnostic_percentile IS NOT NULL) AS diagnostic_cells,
  SAFE_DIVIDE(COUNTIF(diagnostic_percentile IS NOT NULL), COUNT(*))
    AS diagnostic_cell_share,
  SUM(eligible_area_m2) AS total_city_area_m2,
  SUM(IF(diagnostic_percentile IS NOT NULL, eligible_area_m2, 0))
    AS diagnostic_area_m2,
  SAFE_DIVIDE(
    SUM(IF(diagnostic_percentile IS NOT NULL, eligible_area_m2, 0)),
    SUM(eligible_area_m2)
  ) AS diagnostic_area_share,
  SUM(IF(diagnostic_top_10pct_area_flag, eligible_area_m2, 0))
    AS diagnostic_selected_area_m2,
  SAFE_DIVIDE(
    SUM(IF(diagnostic_top_10pct_area_flag, eligible_area_m2, 0)),
    SUM(eligible_area_m2)
  ) AS diagnostic_selected_area_share,
  ANY_VALUE(metric_gate_state) AS metric_gate_state,
  LOGICAL_AND(
    metric_gate_state LIKE 'PASS_%'
  ) AS metric_gate_passed,
  FALSE AS composite_allowed_now,
  'OUTCOME_FREE_NOT_FROZEN' AS evidence_state
FROM `devjam26aug17tpe-1270.subterrat_predictions.sewer_metric_rankings_v0_2_candidate`
GROUP BY variant_id;

ASSERT (
  SELECT
    COUNT(*) = 5
    AND COUNTIF(composite_allowed_now) = 0
    AND COUNTIF(evidence_state != 'OUTCOME_FREE_NOT_FROZEN') = 0
  FROM `devjam26aug17tpe-1270.subterrat_predictions.sewer_metric_quality_v0_2_candidate`
) AS 'v0.2 quality must keep the composite blocked and outcome-free';
