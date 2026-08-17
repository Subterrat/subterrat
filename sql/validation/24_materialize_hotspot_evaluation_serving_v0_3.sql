-- Materializes the post-freeze aggregate-only v0.3 evaluation summary consumed by the
-- internal Cloud Run API. The output has exactly one row for the frozen
-- exact-cell primary metric and one row for the post-lock 200 m descriptive
-- sensitivity. It never exposes report, cell, coordinate, or geometry data.

ASSERT (
  SELECT
    COUNT(*) = 1
    AND COUNTIF(
      variant_id IS DISTINCT FROM
        'v0_3_equal_group_internal_simulation_r150'
    ) = 0
    AND COUNTIF(report_denominator IS DISTINCT FROM 889) = 0
    AND COUNTIF(
      source_csv_sha256 IS DISTINCT FROM
        'b5f9f5223aa514bc3b02159f974efbb72e5cb75333384dde8a98f281305aa37a'
    ) = 0
    AND COUNTIF(
      observed_from IS DISTINCT FROM TIMESTAMP('2026-05-02T23:06:00Z')
      OR observed_to IS DISTINCT FROM TIMESTAMP('2026-07-08T09:56:00Z')
    ) = 0
    AND COUNTIF(
      score_semantics IS DISTINCT FROM
        'ORDINAL_SIMULATION_INDEX_NOT_PROBABILITY'
    ) = 0
    AND COUNTIF(evidence_state IS DISTINCT FROM 'NO_TRUSTED_RESULT') = 0
  FROM
    `devjam26aug17tpe-1270.subterrat_evaluation.rat_radar_report_location_concordance_v0_3`
) AS 'v0.3 exact-cell aggregate identity, window, or evidence state is invalid';

ASSERT (
  SELECT
    COUNT(*) = 1
    AND COUNTIF(ecological_tolerance_m IS DISTINCT FROM 200) = 0
    AND COUNTIF(
      tolerance_role IS DISTINCT FROM
        'POST_LOCK_LITERATURE_ANCHORED_UPPER_LIMIT_SENSITIVITY'
    ) = 0
    AND COUNTIF(report_denominator IS DISTINCT FROM 889) = 0
    AND COUNTIF(
      evaluated_variant_id IS DISTINCT FROM
        'v0_3_equal_group_internal_simulation_r150'
      OR baseline_variant_id IS DISTINCT FROM 'food_market_only_v0_1'
    ) = 0
    AND COUNTIF(
      specification_git_head IS DISTINCT FROM
        'a54ef1dd02c0d6ba692a8ed7a07fd9026686b64a'
    ) = 0
    AND COUNTIF(
      source_csv_sha256 IS DISTINCT FROM
        'b5f9f5223aa514bc3b02159f974efbb72e5cb75333384dde8a98f281305aa37a'
    ) = 0
    AND COUNTIF(
      locked_equivalent_geometry_fixture_sha256 IS NULL
      OR NOT REGEXP_CONTAINS(
        locked_equivalent_geometry_fixture_sha256,
        r'^[0-9a-f]{64}$'
      )
    ) = 0
    AND COUNTIF(
      observed_from IS DISTINCT FROM TIMESTAMP('2026-05-02T15:06:00Z')
      OR observed_to IS DISTINCT FROM TIMESTAMP('2026-07-08T01:56:00Z')
    ) = 0
    AND COUNTIF(evidence_state IS DISTINCT FROM 'NO_TRUSTED_RESULT') = 0
    AND COUNTIF(use_state IS DISTINCT FROM 'INTERNAL_RESEARCH_ONLY') = 0
    AND COUNTIF(operational_use IS DISTINCT FROM 'PROHIBITED') = 0
    AND COUNTIF(public_release_ready IS DISTINCT FROM FALSE) = 0
  FROM
    `devjam26aug17tpe-1270.subterrat_evaluation.rat_radar_ecological_tolerance_200m_v0_3`
) AS 'v0.3 200 m aggregate identity, window, or fail-closed state is invalid';

ASSERT (
  SELECT
    exact.source_csv_sha256 = tolerance.source_csv_sha256
    AND exact.report_denominator = tolerance.report_denominator
    -- The primary renderer encoded Taipei-local clock values as UTC-naive,
    -- while the later 200 m aggregate normalized the same values to UTC.
    -- Preserve both and fail closed on the known +08:00 encoding offset.
    AND exact.observed_from =
      TIMESTAMP_ADD(tolerance.observed_from, INTERVAL 8 HOUR)
    AND exact.observed_to =
      TIMESTAMP_ADD(tolerance.observed_to, INTERVAL 8 HOUR)
  FROM
    `devjam26aug17tpe-1270.subterrat_evaluation.rat_radar_report_location_concordance_v0_3`
      AS exact
  CROSS JOIN
    `devjam26aug17tpe-1270.subterrat_evaluation.rat_radar_ecological_tolerance_200m_v0_3`
      AS tolerance
) AS 'v0.3 exact-cell and 200 m aggregates do not share one outcome snapshot';

CREATE OR REPLACE TABLE
  `devjam26aug17tpe-1270.subterrat_predictions.hotspot_evaluation_summary_v0_3_internal_simulation`
CLUSTER BY ecological_tolerance_m AS
WITH
exact AS (
  SELECT
    variant_id,
    report_denominator,
    overlapping_report_count,
    selected_area_share,
    report_overlap_fraction,
    report_overlap_to_area_ratio,
    food_overlapping_report_count,
    food_selected_area_share,
    food_report_overlap_fraction,
    food_report_overlap_to_area_ratio,
    difference_in_report_overlap_vs_food_v0_1,
    evaluation_kind,
    outcome_role,
    source_csv_sha256,
    observed_from,
    observed_to,
    evidence_state
  FROM
    `devjam26aug17tpe-1270.subterrat_evaluation.rat_radar_report_location_concordance_v0_3`
),
tolerance AS (
  SELECT
    ecological_tolerance_m,
    tolerance_role,
    report_denominator,
    v0_3_overlapping_report_count,
    v0_3_report_overlap_fraction,
    v0_3_buffered_taipei_area_share,
    v0_3_report_overlap_to_area_ratio,
    food_overlapping_report_count,
    food_report_overlap_fraction,
    food_buffered_taipei_area_share,
    food_report_overlap_to_area_ratio,
    difference_in_report_overlap_vs_food_v0_1,
    distance_semantics,
    footprint_semantics,
    calculation_path,
    evaluation_kind,
    outcome_role,
    evaluated_variant_id,
    baseline_variant_id,
    specification_git_head,
    source_csv_sha256,
    locked_equivalent_geometry_fixture_sha256,
    observed_from,
    observed_to,
    evidence_state,
    use_state,
    operational_use,
    public_release_ready
  FROM
    `devjam26aug17tpe-1270.subterrat_evaluation.rat_radar_ecological_tolerance_200m_v0_3`
),
serving_rows AS (
  SELECT
    0 AS ecological_tolerance_m,
    'PRIMARY_EXACT_S2_L15_CELL_CONCORDANCE' AS tolerance_role,
    exact.report_denominator,
    exact.overlapping_report_count AS v0_3_overlapping_report_count,
    exact.report_overlap_fraction AS v0_3_report_overlap_fraction,
    exact.selected_area_share AS v0_3_buffered_taipei_area_share,
    exact.report_overlap_to_area_ratio AS v0_3_report_overlap_to_area_ratio,
    exact.food_overlapping_report_count,
    exact.food_report_overlap_fraction,
    exact.food_selected_area_share AS food_buffered_taipei_area_share,
    exact.food_report_overlap_to_area_ratio,
    exact.difference_in_report_overlap_vs_food_v0_1,
    'EXACT_REPORT_S2_L15_CELL_MEMBERSHIP'
      AS distance_semantics,
    'FROZEN_SELECTED_S2_L15_CELL_ELIGIBLE_AREA_SHARE'
      AS footprint_semantics,
    'BIGQUERY_PRIMARY_CONCORDANCE_AGGREGATE'
      AS calculation_path,
    exact.evaluation_kind,
    exact.outcome_role,
    exact.variant_id AS evaluated_variant_id,
    'food_market_only_v0_1' AS baseline_variant_id,
    tolerance.specification_git_head,
    exact.source_csv_sha256,
    CAST(NULL AS STRING) AS locked_equivalent_geometry_fixture_sha256,
    exact.observed_from,
    exact.observed_to,
    'REPORT_OVERLAP_FRACTION_NOT_PROBABILITY_OR_ACCURACY'
      AS score_semantics,
    '10.1071/WR11149' AS literature_doi,
    'NOT_APPLICABLE_TO_EXACT_CELL_PRIMARY'
      AS literature_interpretation,
    [
      'RETROSPECTIVE_DEVELOPMENT_EXPOSED_REPORT_LOCATION_CONCORDANCE',
      'PRIMARY_SOURCE_TIMESTAMP_ENCODES_TAIPEI_LOCAL_CLOCK_AS_UTC_NAIVE',
      'APPROVED_REPORTS_ARE_NOT_FIELD_VERIFIED_RAT_PRESENCE',
      'REPORT_OVERLAP_IS_NOT_ACCURACY_OR_PROBABILITY'
    ] AS limitation_codes,
    exact.evidence_state,
    tolerance.use_state,
    tolerance.operational_use,
    tolerance.public_release_ready,
    'devjam26aug17tpe-1270.subterrat_evaluation.rat_radar_report_location_concordance_v0_3'
      AS source_table,
    CURRENT_TIMESTAMP() AS materialized_at
  FROM exact
  CROSS JOIN tolerance

  UNION ALL

  SELECT
    tolerance.ecological_tolerance_m,
    tolerance.tolerance_role,
    tolerance.report_denominator,
    tolerance.v0_3_overlapping_report_count,
    tolerance.v0_3_report_overlap_fraction,
    tolerance.v0_3_buffered_taipei_area_share,
    tolerance.v0_3_report_overlap_to_area_ratio,
    tolerance.food_overlapping_report_count,
    tolerance.food_report_overlap_fraction,
    tolerance.food_buffered_taipei_area_share,
    tolerance.food_report_overlap_to_area_ratio,
    tolerance.difference_in_report_overlap_vs_food_v0_1,
    tolerance.distance_semantics,
    tolerance.footprint_semantics,
    tolerance.calculation_path,
    tolerance.evaluation_kind,
    tolerance.outcome_role,
    tolerance.evaluated_variant_id,
    tolerance.baseline_variant_id,
    tolerance.specification_git_head,
    tolerance.source_csv_sha256,
    tolerance.locked_equivalent_geometry_fixture_sha256,
    tolerance.observed_from,
    tolerance.observed_to,
    'REPORT_OVERLAP_FRACTION_NOT_PROBABILITY_OR_ACCURACY'
      AS score_semantics,
    '10.1071/WR11149' AS literature_doi,
    'AVERAGE_MAXIMAL_SEWER_RAT_COVERAGE_NOT_DAILY_MOVEMENT_OR_TAIPEI_RADIUS'
      AS literature_interpretation,
    [
      'POST_LOCK_DESCRIPTIVE_SENSITIVITY_NOT_PRIMARY_VALIDATION',
      'SOURCE_WINDOWS_SHARE_LOCAL_CLOCK_VALUES_BUT_DIFFER_IN_UTC_ENCODING',
      'BUFFER_EXPANDS_GEOGRAPHIC_FOOTPRINT_AND_IS_NOT_ACCURACY',
      'TWO_HUNDRED_METRES_IS_NOT_A_VALIDATED_TAIPEI_ACTIVITY_RADIUS',
      'APPROVED_REPORTS_ARE_NOT_FIELD_VERIFIED_RAT_PRESENCE'
    ] AS limitation_codes,
    tolerance.evidence_state,
    tolerance.use_state,
    tolerance.operational_use,
    tolerance.public_release_ready,
    'devjam26aug17tpe-1270.subterrat_evaluation.rat_radar_ecological_tolerance_200m_v0_3'
      AS source_table,
    CURRENT_TIMESTAMP() AS materialized_at
  FROM tolerance
)
SELECT
  ecological_tolerance_m,
  tolerance_role,
  report_denominator,
  v0_3_overlapping_report_count,
  v0_3_report_overlap_fraction,
  v0_3_buffered_taipei_area_share,
  v0_3_report_overlap_to_area_ratio,
  food_overlapping_report_count,
  food_report_overlap_fraction,
  food_buffered_taipei_area_share,
  food_report_overlap_to_area_ratio,
  difference_in_report_overlap_vs_food_v0_1,
  distance_semantics,
  footprint_semantics,
  calculation_path,
  evaluation_kind,
  outcome_role,
  evaluated_variant_id,
  baseline_variant_id,
  specification_git_head,
  source_csv_sha256,
  locked_equivalent_geometry_fixture_sha256,
  observed_from,
  observed_to,
  score_semantics,
  literature_doi,
  literature_interpretation,
  limitation_codes,
  evidence_state,
  use_state,
  operational_use,
  public_release_ready,
  source_table,
  materialized_at
FROM serving_rows;

ASSERT (
  SELECT
    COUNT(*) = 2
    AND COUNT(*) = COUNT(DISTINCT ecological_tolerance_m)
    AND COUNTIF(ecological_tolerance_m = 0) = 1
    AND COUNTIF(ecological_tolerance_m = 200) = 1
    AND COUNTIF(report_denominator IS DISTINCT FROM 889) = 0
    AND COUNTIF(
      score_semantics IS DISTINCT FROM
        'REPORT_OVERLAP_FRACTION_NOT_PROBABILITY_OR_ACCURACY'
    ) = 0
    AND COUNTIF(evidence_state IS DISTINCT FROM 'NO_TRUSTED_RESULT') = 0
    AND COUNTIF(use_state IS DISTINCT FROM 'INTERNAL_RESEARCH_ONLY') = 0
    AND COUNTIF(operational_use IS DISTINCT FROM 'PROHIBITED') = 0
    AND COUNTIF(public_release_ready IS DISTINCT FROM FALSE) = 0
    AND COUNTIF(literature_doi IS DISTINCT FROM '10.1071/WR11149') = 0
    AND COUNTIF(ARRAY_LENGTH(limitation_codes) = 0) = 0
    AND COUNTIF(
      v0_3_overlapping_report_count IS NULL
      OR v0_3_overlapping_report_count < 0
      OR v0_3_overlapping_report_count > report_denominator
      OR food_overlapping_report_count IS NULL
      OR food_overlapping_report_count < 0
      OR food_overlapping_report_count > report_denominator
      OR v0_3_report_overlap_fraction IS NULL
      OR v0_3_report_overlap_fraction < 0
      OR v0_3_report_overlap_fraction > 1
      OR food_report_overlap_fraction IS NULL
      OR food_report_overlap_fraction < 0
      OR food_report_overlap_fraction > 1
      OR v0_3_buffered_taipei_area_share IS NULL
      OR v0_3_buffered_taipei_area_share <= 0
      OR v0_3_buffered_taipei_area_share > 1
      OR food_buffered_taipei_area_share IS NULL
      OR food_buffered_taipei_area_share <= 0
      OR food_buffered_taipei_area_share > 1
      OR v0_3_report_overlap_to_area_ratio IS NULL
      OR food_report_overlap_to_area_ratio IS NULL
      OR difference_in_report_overlap_vs_food_v0_1 IS NULL
    ) = 0
  FROM
    `devjam26aug17tpe-1270.subterrat_predictions.hotspot_evaluation_summary_v0_3_internal_simulation`
) AS 'v0.3 evaluation serving output cardinality or fail-closed state is invalid';

ASSERT (
  SELECT
    COUNT(*) = 1
    AND COUNTIF(
      serving.report_denominator IS DISTINCT FROM source.report_denominator
      OR serving.v0_3_overlapping_report_count IS DISTINCT FROM
        source.overlapping_report_count
      OR serving.v0_3_report_overlap_fraction IS DISTINCT FROM
        source.report_overlap_fraction
      OR serving.v0_3_buffered_taipei_area_share IS DISTINCT FROM
        source.selected_area_share
      OR serving.v0_3_report_overlap_to_area_ratio IS DISTINCT FROM
        source.report_overlap_to_area_ratio
      OR serving.food_overlapping_report_count IS DISTINCT FROM
        source.food_overlapping_report_count
      OR serving.food_report_overlap_fraction IS DISTINCT FROM
        source.food_report_overlap_fraction
      OR serving.food_buffered_taipei_area_share IS DISTINCT FROM
        source.food_selected_area_share
      OR serving.food_report_overlap_to_area_ratio IS DISTINCT FROM
        source.food_report_overlap_to_area_ratio
      OR serving.difference_in_report_overlap_vs_food_v0_1 IS DISTINCT FROM
        source.difference_in_report_overlap_vs_food_v0_1
    ) = 0
  FROM
    `devjam26aug17tpe-1270.subterrat_predictions.hotspot_evaluation_summary_v0_3_internal_simulation`
      AS serving
  CROSS JOIN
    `devjam26aug17tpe-1270.subterrat_evaluation.rat_radar_report_location_concordance_v0_3`
      AS source
  WHERE serving.ecological_tolerance_m = 0
) AS 'v0.3 exact-cell serving row does not reproduce the primary aggregate';

ASSERT (
  SELECT
    COUNT(*) = 1
    AND COUNTIF(
      serving.report_denominator IS DISTINCT FROM source.report_denominator
      OR serving.v0_3_overlapping_report_count IS DISTINCT FROM
        source.v0_3_overlapping_report_count
      OR serving.v0_3_report_overlap_fraction IS DISTINCT FROM
        source.v0_3_report_overlap_fraction
      OR serving.v0_3_buffered_taipei_area_share IS DISTINCT FROM
        source.v0_3_buffered_taipei_area_share
      OR serving.v0_3_report_overlap_to_area_ratio IS DISTINCT FROM
        source.v0_3_report_overlap_to_area_ratio
      OR serving.food_overlapping_report_count IS DISTINCT FROM
        source.food_overlapping_report_count
      OR serving.food_report_overlap_fraction IS DISTINCT FROM
        source.food_report_overlap_fraction
      OR serving.food_buffered_taipei_area_share IS DISTINCT FROM
        source.food_buffered_taipei_area_share
      OR serving.food_report_overlap_to_area_ratio IS DISTINCT FROM
        source.food_report_overlap_to_area_ratio
      OR serving.difference_in_report_overlap_vs_food_v0_1 IS DISTINCT FROM
        source.difference_in_report_overlap_vs_food_v0_1
    ) = 0
  FROM
    `devjam26aug17tpe-1270.subterrat_predictions.hotspot_evaluation_summary_v0_3_internal_simulation`
      AS serving
  CROSS JOIN
    `devjam26aug17tpe-1270.subterrat_evaluation.rat_radar_ecological_tolerance_200m_v0_3`
      AS source
  WHERE serving.ecological_tolerance_m = 200
) AS 'v0.3 200 m serving row does not reproduce the source aggregate';
