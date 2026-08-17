-- Creates the one-shot retrospective concordance gate after the reviewed,
-- outcome-blinded internal simulation exists. This is neither a public release
-- nor a prospective prediction freeze.
--
-- Required named query parameters: same values used for SQL 16.
--   specification_git_head STRING
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
) AS 'v0.3 concordance lock parameters are invalid';

ASSERT (
  SELECT
    COUNT(*) = 3420 * 7
    AND COUNT(*) = COUNT(DISTINCT CONCAT(variant_id, ':', CAST(cell_id AS STRING)))
    AND COUNT(DISTINCT variant_id) = 7
    AND COUNTIF(specification_state != 'LOCKED') = 0
    AND COUNTIF(use_state != 'INTERNAL_SIMULATION_ONLY') = 0
    AND COUNTIF(evidence_state != 'NO_TRUSTED_RESULT') = 0
    AND COUNTIF(operational_use != 'PROHIBITED') = 0
    AND COUNTIF(score_semantics != 'ORDINAL_SIMULATION_INDEX_NOT_PROBABILITY') = 0
    AND COUNTIF(specification_git_head != @specification_git_head) = 0
    AND COUNTIF(specification_source != @repository_state) = 0
    AND COUNTIF(review_verdict != @review_verdict) = 0
    AND COUNTIF(review_receipt_sha256 != @review_receipt_sha256) = 0
    AND COUNTIF(scenario_contract_sha256 != @scenario_contract_sha256) = 0
    AND COUNTIF(scenario_sql_sha256 != @scenario_sql_sha256) = 0
    AND COUNTIF(
      urban_renewal_source_snapshot_id
      != @urban_renewal_source_snapshot_id
    ) = 0
  FROM
    `devjam26aug17tpe-1270.subterrat_predictions.hotspot_scenarios_v0_3_internal_simulation`
) AS 'v0.3 rows do not match the committed reviewed artifact identity';

ASSERT (
  SELECT
    COUNT(*) = 7
    AND COUNTIF(public_release_ready) = 0
    AND COUNTIF(operational_use_ready) = 0
    AND COUNTIF(evidence_state != 'NO_TRUSTED_RESULT') = 0
  FROM
    `devjam26aug17tpe-1270.subterrat_predictions.hotspot_scenario_quality_v0_3_internal_simulation`
) AS 'v0.3 quality table is missing or a prohibited gate is open';

CREATE OR REPLACE TABLE
  `devjam26aug17tpe-1270.subterrat_predictions.hotspot_scenarios_v0_3_locked_internal_simulation`
CLUSTER BY variant_id, cell_id AS
SELECT
  *,
  'LOCKED_AWAITING_ONE_SHOT_RETROSPECTIVE_CONCORDANCE'
    AS retrospective_concordance_state
FROM
  `devjam26aug17tpe-1270.subterrat_predictions.hotspot_scenarios_v0_3_internal_simulation`
WHERE variant_id IN (
  'v0_3_equal_group_internal_simulation_r150',
  'food_market_only_v0_1'
);

ASSERT (
  SELECT
    COUNT(*) = 3420 * 2
    AND COUNT(DISTINCT variant_id) = 2
    AND COUNTIF(
      variant_id = 'v0_3_equal_group_internal_simulation_r150'
    ) = 3420
    AND COUNTIF(variant_id = 'food_market_only_v0_1') = 3420
    AND COUNT(DISTINCT IF(
      variant_id = 'v0_3_equal_group_internal_simulation_r150',
      cell_id,
      NULL
    )) = 3420
    AND COUNT(DISTINCT IF(
      variant_id = 'food_market_only_v0_1',
      cell_id,
      NULL
    )) = 3420
    AND COUNTIF(variant_id NOT IN (
      'v0_3_equal_group_internal_simulation_r150',
      'food_market_only_v0_1'
    )) = 0
  FROM
    `devjam26aug17tpe-1270.subterrat_predictions.hotspot_scenarios_v0_3_locked_internal_simulation`
) AS 'v0.3 concordance lock must contain only the composite and food baseline';

CREATE OR REPLACE TABLE
  `devjam26aug17tpe-1270.subterrat_predictions.hotspot_scenario_lock_manifest_v0_3` AS
SELECT
  'v0.3-internal-simulation-concordance-lock' AS lock_id,
  'LOCKED_AWAITING_ONE_SHOT_RETROSPECTIVE_CONCORDANCE' AS lock_status,
  'OUTCOME_BLINDED_INTERNAL_SIMULATION_ONLY' AS lock_kind,
  CURRENT_TIMESTAMP() AS locked_at,
  'devjam26aug17tpe-1270' AS project_id,
  @specification_git_head AS specification_git_head,
  @repository_state AS specification_source,
  @review_verdict AS review_verdict,
  @review_receipt_sha256 AS review_receipt_sha256,
  @scenario_contract_sha256 AS scenario_contract_sha256,
  @scenario_sql_sha256 AS scenario_sql_sha256,
  @urban_renewal_source_snapshot_id AS urban_renewal_source_snapshot_id,
  [
    'v0_3_equal_group_internal_simulation_r150',
    'food_market_only_v0_1'
  ] AS included_variants,
  [
    'food_market',
    'sewer_attribute_index',
    'approved_rebuilding_admin_site_cell_footprint_buffer_150m'
  ] AS frontend_component_layers,
  'DENY' AS component_outcome_concordance,
  'DENY' AS raw_outcome_access_before_lock,
  'INTERNAL_SIMULATION_ONLY' AS use_state,
  'NO_TRUSTED_RESULT' AS evidence_state,
  'PROHIBITED' AS operational_use,
  FALSE AS public_release_ready;

ASSERT (
  SELECT
    COUNT(*) = 1
    AND ANY_VALUE(lock_status) =
      'LOCKED_AWAITING_ONE_SHOT_RETROSPECTIVE_CONCORDANCE'
    AND ARRAY_TO_STRING(ANY_VALUE(included_variants), ',') =
      'v0_3_equal_group_internal_simulation_r150,food_market_only_v0_1'
    AND ARRAY_TO_STRING(ANY_VALUE(frontend_component_layers), ',') =
      'food_market,sewer_attribute_index,approved_rebuilding_admin_site_cell_footprint_buffer_150m'
    AND ANY_VALUE(raw_outcome_access_before_lock) = 'DENY'
    AND ANY_VALUE(component_outcome_concordance) = 'DENY'
    AND ANY_VALUE(use_state) = 'INTERNAL_SIMULATION_ONLY'
    AND ANY_VALUE(evidence_state) = 'NO_TRUSTED_RESULT'
    AND ANY_VALUE(operational_use) = 'PROHIBITED'
    AND COUNTIF(public_release_ready) = 0
  FROM
    `devjam26aug17tpe-1270.subterrat_predictions.hotspot_scenario_lock_manifest_v0_3`
) AS 'v0.3 retrospective concordance lock manifest is invalid';
