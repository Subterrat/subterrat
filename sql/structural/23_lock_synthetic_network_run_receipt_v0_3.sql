-- Creates the deterministic internal run receipt only after all six canonical
-- artifact hashes were independently computed and verified. This is not a
-- public release, retrospective validation, or operational approval.

ASSERT (
  @repository_state = 'COMMITTED_SOURCE'
  AND @review_verdict = 'APPROVE_FOR_INTERNAL_IMPLEMENTATION'
  AND REGEXP_CONTAINS(@contract_hash, r'^[0-9a-f]{64}$')
  AND REGEXP_CONTAINS(@finalized_input_manifest_hash, r'^[0-9a-f]{64}$')
  AND REGEXP_CONTAINS(@artifact_schema_contract_hash, r'^[0-9a-f]{64}$')
  AND REGEXP_CONTAINS(@api_schema_contract_hash, r'^[0-9a-f]{64}$')
  AND REGEXP_CONTAINS(@sql_hash, r'^[0-9a-f]{64}$')
  AND REGEXP_CONTAINS(@code_revision, r'^[0-9a-f]{40}$')
  AND REGEXP_CONTAINS(@cell_links_hash, r'^[0-9a-f]{64}$')
  AND REGEXP_CONTAINS(@transitions_hash, r'^[0-9a-f]{64}$')
  AND REGEXP_CONTAINS(@states_hash, r'^[0-9a-f]{64}$')
  AND REGEXP_CONTAINS(@quality_hash, r'^[0-9a-f]{64}$')
  AND REGEXP_CONTAINS(@map_cells_hash, r'^[0-9a-f]{64}$')
  AND REGEXP_CONTAINS(@schematic_links_hash, r'^[0-9a-f]{64}$')
) AS 'network redistribution receipt identity is incomplete';

DECLARE v_run_id STRING DEFAULT LOWER(TO_HEX(SHA256(CAST(CONCAT(
  @contract_hash, CHR(31),
  @finalized_input_manifest_hash, CHR(31),
  @sql_hash, CHR(31),
  @code_revision, CHR(31),
  @cell_universe_content_hash, CHR(31),
  @food_seed_content_hash, CHR(31),
  @pipe_geometry_content_hash, CHR(31),
  @sewer_attribute_content_hash, CHR(31),
  @parent_v0_3_lock_content_hash
) AS BYTES))));

ASSERT (
  SELECT
    COUNT(*) = 1
    AND ANY_VALUE(lock_id) = 'v0.3-internal-simulation-concordance-lock'
    AND ANY_VALUE(lock_status) =
      'LOCKED_AWAITING_ONE_SHOT_RETROSPECTIVE_CONCORDANCE'
    AND ANY_VALUE(raw_outcome_access_before_lock) = 'DENY'
    AND ANY_VALUE(use_state) = 'INTERNAL_SIMULATION_ONLY'
    AND ANY_VALUE(evidence_state) = 'NO_TRUSTED_RESULT'
    AND ANY_VALUE(operational_use) = 'PROHIBITED'
    AND COUNTIF(public_release_ready) = 0
  FROM
    `devjam26aug17tpe-1270.subterrat_predictions.hotspot_scenario_lock_manifest_v0_3`
  WHERE lock_id = 'v0.3-internal-simulation-concordance-lock'
) AS 'committed parent v0.3 lock is absent or invalid';

ASSERT (
  (
    SELECT COUNT(DISTINCT run_id) = 1 AND ANY_VALUE(run_id) = v_run_id
    FROM
      `devjam26aug17tpe-1270.subterrat_features.synthetic_network_cell_links_v0_3_candidate`
  )
  AND (
    SELECT COUNT(DISTINCT run_id) = 1 AND ANY_VALUE(run_id) = v_run_id
    FROM
      `devjam26aug17tpe-1270.subterrat_simulations.synthetic_network_transitions_v0_3_internal_simulation`
  )
  AND (
    SELECT COUNT(DISTINCT run_id) = 1 AND ANY_VALUE(run_id) = v_run_id
    FROM
      `devjam26aug17tpe-1270.subterrat_simulations.synthetic_network_states_v0_3_internal_simulation`
  )
  AND (
    SELECT COUNT(DISTINCT run_id) = 1 AND ANY_VALUE(run_id) = v_run_id
    FROM
      `devjam26aug17tpe-1270.subterrat_simulations.synthetic_network_quality_v0_3_internal_simulation`
  )
) AS 'canonical artifacts do not share the expected run ID';

CREATE OR REPLACE TABLE
  `devjam26aug17tpe-1270.subterrat_simulations.synthetic_network_run_receipt_v0_3_internal_simulation`
AS
SELECT
  v_run_id AS run_id,
  @contract_hash AS contract_hash,
  @finalized_input_manifest_hash AS finalized_input_manifest_hash,
  @artifact_schema_contract_hash AS artifact_schema_contract_hash,
  @api_schema_contract_hash AS api_schema_contract_hash,
  @sql_hash AS sql_hash,
  @code_revision AS code_revision,
  STRUCT(
    @cell_links_hash AS cell_links,
    @transitions_hash AS transitions,
    @states_hash AS states,
    @quality_hash AS quality,
    @map_cells_hash AS map_cells,
    @schematic_links_hash AS schematic_links
  ) AS output_table_hashes,
  'DETERMINISTIC_SYNTHETIC_NETWORK_REDISTRIBUTION' AS model_kind,
  'INTERNAL_SIMULATION_ONLY' AS use_state,
  'NO_TRUSTED_RESULT' AS evidence_state,
  'PROHIBITED' AS operational_use,
  FALSE AS retrospective_validation_complete,
  FALSE AS public_release_ready,
  FALSE AS operational_use_ready;
