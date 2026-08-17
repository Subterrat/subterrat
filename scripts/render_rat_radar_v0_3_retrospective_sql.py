#!/usr/bin/env python3
"""Render lock-gated v0.3 retrospective concordance BigQuery SQL.

The generated SQL embeds only anonymous report hashes and S2 Level 15 cell
IDs. Raw descriptions, photos, addresses, and coordinates are never persisted
in BigQuery. The query can run only after the reviewed v0.3 internal simulation
has a committed artifact identity and a concordance lock.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from scripts.render_rat_radar_retrospective_sql import load_outcomes, sha256_file


def render_sql(csv_path: Path) -> str:
    outcomes, observed_from, observed_to = load_outcomes(csv_path)
    source_sha256 = sha256_file(csv_path)
    structs = ",\n    ".join(
        f"STRUCT('{report_id}' AS report_id, CAST({cell_id} AS INT64) AS cell_id)"
        for report_id, cell_id in outcomes
    )
    denominator = len(outcomes)
    return f"""-- Generated one-shot retrospective report-location concordance SQL.
ASSERT (
  SELECT
    COUNT(*) = 1
    AND ANY_VALUE(lock_status) =
      'LOCKED_AWAITING_ONE_SHOT_RETROSPECTIVE_CONCORDANCE'
    AND ANY_VALUE(raw_outcome_access_before_lock) = 'DENY'
    AND ANY_VALUE(use_state) = 'INTERNAL_SIMULATION_ONLY'
    AND ANY_VALUE(evidence_state) = 'NO_TRUSTED_RESULT'
    AND ANY_VALUE(operational_use) = 'PROHIBITED'
    AND COUNTIF(public_release_ready) = 0
  FROM
    `devjam26aug17tpe-1270.subterrat_predictions.hotspot_scenario_lock_manifest_v0_3`
) AS 'v0.3 concordance is forbidden before the committed reviewed lock';

CREATE SCHEMA IF NOT EXISTS
  `devjam26aug17tpe-1270.subterrat_evaluation`
OPTIONS(location = 'asia-east1');

-- Primary comparison: each map is evaluated as delivered, including each
-- map's own unscored support.
CREATE OR REPLACE TABLE
  `devjam26aug17tpe-1270.subterrat_evaluation.rat_radar_report_location_concordance_v0_3` AS
WITH
outcome AS (
  SELECT * FROM UNNEST([
    {structs}
  ])
),
locked AS (
  SELECT *
  FROM
    `devjam26aug17tpe-1270.subterrat_predictions.hotspot_scenarios_v0_3_locked_internal_simulation`
  WHERE
    retrospective_concordance_state =
      'LOCKED_AWAITING_ONE_SHOT_RETROSPECTIVE_CONCORDANCE'
),
variant_area AS (
  SELECT
    variant_id,
    SAFE_DIVIDE(
      SUM(IF(preregistered_selected_scenario_area_flag, eligible_area_m2, 0)),
      SUM(eligible_area_m2)
    ) AS selected_area_share,
    SAFE_DIVIDE(
      SUM(IF(simulation_index IS NOT NULL, eligible_area_m2, 0)),
      SUM(eligible_area_m2)
    ) AS scoreable_area_share
  FROM locked
  GROUP BY variant_id
),
grid_coverage AS (
  SELECT COUNT(DISTINCT outcome.report_id) AS matched_grid_report_count
  FROM outcome
  JOIN (SELECT DISTINCT cell_id FROM locked) USING (cell_id)
),
overlap AS (
  SELECT
    locked.variant_id,
    COUNT(DISTINCT IF(
      locked.preregistered_selected_scenario_area_flag,
      outcome.report_id,
      NULL
    )) AS overlapping_report_count,
    COUNT(DISTINCT IF(
      locked.simulation_index IS NULL,
      outcome.report_id,
      NULL
    )) AS unscored_report_count
  FROM locked
  LEFT JOIN outcome USING (cell_id)
  GROUP BY locked.variant_id
),
metrics AS (
  SELECT
    overlap.variant_id,
    {denominator} AS report_denominator,
    grid_coverage.matched_grid_report_count,
    {denominator} - grid_coverage.matched_grid_report_count
      AS unmatched_grid_report_count,
    overlap.unscored_report_count,
    overlap.overlapping_report_count,
    variant_area.selected_area_share,
    variant_area.scoreable_area_share,
    SAFE_DIVIDE(overlap.overlapping_report_count, {denominator})
      AS report_overlap_fraction,
    SAFE_DIVIDE(overlap.unscored_report_count, {denominator})
      AS unscored_report_fraction,
    SAFE_DIVIDE(
      SAFE_DIVIDE(overlap.overlapping_report_count, {denominator}),
      variant_area.selected_area_share
    ) AS report_overlap_to_area_ratio
  FROM overlap
  JOIN variant_area USING (variant_id)
  CROSS JOIN grid_coverage
),
food AS (
  SELECT report_overlap_fraction AS food_report_overlap_fraction
  FROM metrics
  WHERE variant_id = 'food_market_only_v0_1'
)
SELECT
  metrics.*,
  food.food_report_overlap_fraction,
  metrics.report_overlap_fraction - food.food_report_overlap_fraction
    AS difference_in_report_overlap_vs_food_v0_1,
  'PRIMARY_CITYWIDE_MAP_AS_DELIVERED' AS comparison_scope,
  'ONE_SHOT_POST_LOCK_RETROSPECTIVE_REPORT_LOCATION_CONCORDANCE'
    AS evaluation_kind,
  'CONCORDANCE_ONLY_NOT_TRAINING_SELECTION_TUNING_OR_ATTRIBUTION'
    AS outcome_role,
  '{source_sha256}' AS source_csv_sha256,
  TIMESTAMP('{observed_from}') AS observed_from,
  TIMESTAMP('{observed_to}') AS observed_to,
  'ORDINAL_SIMULATION_INDEX_NOT_PROBABILITY' AS score_semantics,
  'NO_TRUSTED_RESULT' AS evidence_state
FROM metrics
CROSS JOIN food;

ASSERT (
  SELECT
    COUNT(*) = 7
    AND COUNTIF(report_denominator != {denominator}) = 0
    AND COUNTIF(
      outcome_role
      != 'CONCORDANCE_ONLY_NOT_TRAINING_SELECTION_TUNING_OR_ATTRIBUTION'
    ) = 0
    AND COUNTIF(score_semantics != 'ORDINAL_SIMULATION_INDEX_NOT_PROBABILITY') = 0
    AND COUNTIF(evidence_state != 'NO_TRUSTED_RESULT') = 0
  FROM
    `devjam26aug17tpe-1270.subterrat_evaluation.rat_radar_report_location_concordance_v0_3`
) AS 'v0.3 citywide concordance identity or evidence boundary is invalid';

-- Secondary comparison: both the v0.3 index and frozen food v0.1 are reranked
-- on the exact v0.3 scoreable support. Selection is the top 10% of that common
-- support by eligible area, with all threshold ties included.
CREATE OR REPLACE TABLE
  `devjam26aug17tpe-1270.subterrat_evaluation.rat_radar_common_support_concordance_v0_3` AS
WITH
outcome AS (
  SELECT * FROM UNNEST([
    {structs}
  ])
),
locked AS (
  SELECT *
  FROM
    `devjam26aug17tpe-1270.subterrat_predictions.hotspot_scenarios_v0_3_locked_internal_simulation`
  WHERE
    retrospective_concordance_state =
      'LOCKED_AWAITING_ONE_SHOT_RETROSPECTIVE_CONCORDANCE'
),
common_support AS (
  SELECT
    v0_3.cell_id,
    v0_3.eligible_area_m2,
    v0_3.simulation_index AS v0_3_index,
    food.simulation_index AS food_index
  FROM locked AS v0_3
  JOIN locked AS food USING (cell_id)
  WHERE
    v0_3.variant_id = 'v0_3_equal_group_internal_simulation_r150'
    AND food.variant_id = 'food_market_only_v0_1'
    AND v0_3.simulation_index IS NOT NULL
    AND food.simulation_index IS NOT NULL
),
variant_rows AS (
  SELECT
    common_support.cell_id,
    common_support.eligible_area_m2,
    variant.variant_id,
    variant.simulation_index
  FROM common_support
  CROSS JOIN UNNEST([
    STRUCT(
      'v0_3_equal_group_internal_simulation_r150' AS variant_id,
      v0_3_index AS simulation_index
    ),
    STRUCT(
      'food_market_only_v0_1_reranked_on_v0_3_support' AS variant_id,
      food_index AS simulation_index
    )
  ]) AS variant
),
area_ranked AS (
  SELECT
    *,
    SUM(eligible_area_m2) OVER (
      PARTITION BY variant_id
      ORDER BY simulation_index DESC, cell_id
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_common_support_area_m2,
    SUM(eligible_area_m2) OVER (PARTITION BY variant_id)
      AS total_common_support_area_m2
  FROM variant_rows
),
thresholds AS (
  SELECT
    variant_id,
    MIN(simulation_index) AS threshold_index
  FROM area_ranked
  WHERE
    cumulative_common_support_area_m2 - eligible_area_m2
      < total_common_support_area_m2 * 0.10
  GROUP BY variant_id
),
selected AS (
  SELECT
    area_ranked.*,
    area_ranked.simulation_index >= thresholds.threshold_index
      AS selected_common_support_area_flag
  FROM area_ranked
  JOIN thresholds USING (variant_id)
),
common_report_coverage AS (
  SELECT COUNT(DISTINCT outcome.report_id) AS common_support_report_count
  FROM outcome
  JOIN (SELECT DISTINCT cell_id FROM common_support) USING (cell_id)
),
metrics AS (
  SELECT
    selected.variant_id,
    {denominator} AS citywide_report_denominator,
    common_report_coverage.common_support_report_count,
    {denominator} - common_report_coverage.common_support_report_count
      AS outside_common_support_report_count,
    COUNT(DISTINCT IF(
      selected.selected_common_support_area_flag,
      outcome.report_id,
      NULL
    )) AS overlapping_report_count,
    SAFE_DIVIDE(
      SUM(IF(selected.selected_common_support_area_flag, eligible_area_m2, 0)),
      ANY_VALUE(total_common_support_area_m2)
    ) AS selected_area_fraction_of_common_support
  FROM selected
  LEFT JOIN outcome USING (cell_id)
  CROSS JOIN common_report_coverage
  GROUP BY selected.variant_id, common_report_coverage.common_support_report_count
),
fractions AS (
  SELECT
    *,
    SAFE_DIVIDE(overlapping_report_count, common_support_report_count)
      AS report_overlap_fraction_on_common_support,
    SAFE_DIVIDE(
      {denominator} - common_support_report_count,
      {denominator}
    ) AS outside_common_support_report_fraction,
    SAFE_DIVIDE(
      SAFE_DIVIDE(overlapping_report_count, common_support_report_count),
      selected_area_fraction_of_common_support
    ) AS report_overlap_to_area_ratio_on_common_support
  FROM metrics
),
food AS (
  SELECT report_overlap_fraction_on_common_support AS food_report_overlap_fraction
  FROM fractions
  WHERE variant_id = 'food_market_only_v0_1_reranked_on_v0_3_support'
)
SELECT
  fractions.*,
  food.food_report_overlap_fraction,
  fractions.report_overlap_fraction_on_common_support
    - food.food_report_overlap_fraction
    AS difference_in_report_overlap_vs_food_v0_1,
  'SECONDARY_EXACT_V0_3_COMMON_SUPPORT' AS comparison_scope,
  'ONE_SHOT_POST_LOCK_RETROSPECTIVE_REPORT_LOCATION_CONCORDANCE'
    AS evaluation_kind,
  'CONCORDANCE_ONLY_NOT_TRAINING_SELECTION_TUNING_OR_ATTRIBUTION'
    AS outcome_role,
  '{source_sha256}' AS source_csv_sha256,
  TIMESTAMP('{observed_from}') AS observed_from,
  TIMESTAMP('{observed_to}') AS observed_to,
  'ORDINAL_SIMULATION_INDEX_NOT_PROBABILITY' AS score_semantics,
  'NO_TRUSTED_RESULT' AS evidence_state
FROM fractions
CROSS JOIN food;

ASSERT (
  SELECT
    COUNT(*) = 2
    AND COUNTIF(citywide_report_denominator != {denominator}) = 0
    AND COUNT(DISTINCT common_support_report_count) = 1
    AND COUNTIF(
      selected_area_fraction_of_common_support < 0
      OR selected_area_fraction_of_common_support > 1
    ) = 0
    AND COUNTIF(
      outcome_role
      != 'CONCORDANCE_ONLY_NOT_TRAINING_SELECTION_TUNING_OR_ATTRIBUTION'
    ) = 0
    AND COUNTIF(score_semantics != 'ORDINAL_SIMULATION_INDEX_NOT_PROBABILITY') = 0
    AND COUNTIF(evidence_state != 'NO_TRUSTED_RESULT') = 0
  FROM
    `devjam26aug17tpe-1270.subterrat_evaluation.rat_radar_common_support_concordance_v0_3`
) AS 'v0.3 common-support concordance identity or evidence boundary is invalid';
"""


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("csv", type=Path)
    args = parser.parse_args()
    print(render_sql(args.csv))


if __name__ == "__main__":
    main()
