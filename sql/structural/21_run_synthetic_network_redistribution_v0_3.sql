-- Builds canonical transition, state, map, and schematic-link artifacts for
-- the approved internal synthetic network redistribution challenger.
-- Iterations 0..8 are abstract iterations with no calendar-time mapping.
-- Required named parameters are identical to SQL 20.

ASSERT (
  @repository_state = 'COMMITTED_SOURCE'
  AND @review_verdict = 'APPROVE_FOR_INTERNAL_IMPLEMENTATION'
  AND REGEXP_CONTAINS(@contract_hash, r'^[0-9a-f]{64}$')
  AND REGEXP_CONTAINS(@finalized_input_manifest_hash, r'^[0-9a-f]{64}$')
  AND REGEXP_CONTAINS(@artifact_schema_contract_hash, r'^[0-9a-f]{64}$')
  AND REGEXP_CONTAINS(@api_schema_contract_hash, r'^[0-9a-f]{64}$')
  AND REGEXP_CONTAINS(@sql_hash, r'^[0-9a-f]{64}$')
  AND REGEXP_CONTAINS(@code_revision, r'^[0-9a-f]{40}$')
  AND REGEXP_CONTAINS(@cell_universe_content_hash, r'^[0-9a-f]{64}$')
  AND REGEXP_CONTAINS(@food_seed_content_hash, r'^[0-9a-f]{64}$')
  AND REGEXP_CONTAINS(@pipe_geometry_content_hash, r'^[0-9a-f]{64}$')
  AND REGEXP_CONTAINS(@sewer_attribute_content_hash, r'^[0-9a-f]{64}$')
  AND REGEXP_CONTAINS(@parent_v0_3_lock_content_hash, r'^[0-9a-f]{64}$')
) AS 'network redistribution artifact identity is incomplete';

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
DECLARE iteration_number INT64 DEFAULT 1;

CREATE TEMP TABLE cells AS
SELECT
  cell.cell_id,
  cell.eligible_geom,
  ROUND(CAST(cell.centroid_longitude AS BIGNUMERIC), 7, 'ROUND_HALF_EVEN')
    AS centroid_longitude_7,
  ROUND(CAST(cell.centroid_latitude AS BIGNUMERIC), 7, 'ROUND_HALF_EVEN')
    AS centroid_latitude_7,
  ROUND(CAST(cell.eligible_area_m2 AS BIGNUMERIC), 6, 'ROUND_HALF_EVEN')
    AS eligible_area_m2_6,
  ROUND(CAST(food.food_score AS BIGNUMERIC), 12, 'ROUND_HALF_EVEN')
    AS food_score_12
FROM `devjam26aug17tpe-1270.subterrat_curated.analysis_cells` AS cell
JOIN `devjam26aug17tpe-1270.subterrat_predictions.map_hotspot_cells_t0` AS food
  USING (cell_id)
WHERE
  cell.grid_version = 'taipei_county_1140318_s2_l15_v1'
  AND food.freeze_id = 't0-layerwise-development-20260817-v2'
  AND food.score_semantics = 'LAYER_SCORE_NOT_PROBABILITY';

ASSERT (
  SELECT
    COUNT(*) = 3420
    AND COUNT(DISTINCT cell_id) = 3420
    AND COUNTIF(food_score_12 IS NULL OR eligible_area_m2_6 <= 0) = 0
  FROM cells
) AS 'canonical food/cell seed inputs are invalid';

CREATE TEMP TABLE seeds AS
WITH raw AS (
  SELECT
    cell_id,
    ROUND(
      food_score_12 * eligible_area_m2_6,
      18,
      'ROUND_HALF_EVEN'
    ) AS stored_raw_seed
  FROM cells
),
total AS (
  SELECT SUM(stored_raw_seed) AS raw_seed_total FROM raw
)
SELECT
  cell_id,
  ROUND(
    stored_raw_seed / raw_seed_total,
    24,
    'ROUND_HALF_EVEN'
  ) AS stored_source_seed
FROM raw
CROSS JOIN total;

ASSERT (
  SELECT
    COUNT(*) = 3420
    AND ABS(SUM(stored_source_seed) - CAST(1 AS BIGNUMERIC))
      <= CAST('0.000000001' AS BIGNUMERIC)
  FROM seeds
) AS 'canonical source seed mass is invalid';

CREATE TEMP TABLE sewer_attributes AS
WITH pivoted AS (
  SELECT
    cell_id,
    COUNT(DISTINCT variant_id) AS metric_count,
    COUNTIF(diagnostic_percentile IS NOT NULL) AS nonnull_count,
    AVG(ROUND(
      CAST(diagnostic_percentile AS BIGNUMERIC),
      12,
      'ROUND_HALF_EVEN'
    )) AS attribute_unrounded
  FROM
    `devjam26aug17tpe-1270.subterrat_predictions.sewer_metric_rankings_v0_2_candidate`
  WHERE
    source_snapshot_id =
      '979ee9ac61c536177f4ee929afb2fcf44313023f6ae6d3f0585a7ffd26ea0911'
    AND variant_id IN (
      'sewer_system_type',
      'surface_elevation',
      'connected_pipe_diameter',
      'connected_pipe_depth',
      'connected_pipe_age'
    )
  GROUP BY cell_id
)
SELECT
  cell_id,
  IF(
    metric_count = 5 AND nonnull_count = 5,
    ROUND(attribute_unrounded, 12, 'ROUND_HALF_EVEN'),
    NULL
  ) AS sewer_attribute_index
FROM pivoted;

CREATE TEMP TABLE scenarios AS
SELECT *
FROM UNNEST([
  STRUCT(
    'n0_uniform_sewer_link_comparator' AS scenario_id,
    CAST('0.65' AS BIGNUMERIC) AS self_bucket,
    CAST('0.35' AS BIGNUMERIC) AS sewer_bucket,
    CAST('0.00' AS BIGNUMERIC) AS generic_bucket,
    TRUE AS uniform_sewer_distribution
  ),
  STRUCT(
    'n1_metric_weighted_sewer_links',
    CAST('0.65' AS BIGNUMERIC),
    CAST('0.35' AS BIGNUMERIC),
    CAST('0.00' AS BIGNUMERIC),
    FALSE
  ),
  STRUCT(
    'n2_generic_cell_adjacency_sensitivity',
    CAST('0.55' AS BIGNUMERIC),
    CAST('0.35' AS BIGNUMERIC),
    CAST('0.10' AS BIGNUMERIC),
    FALSE
  )
]);

CREATE TEMP TABLE directed_links AS
SELECT
  link.link_class,
  link.from_cell_id,
  link.to_cell_id,
  link.metric_eligible,
  link.route_weight
FROM
  `devjam26aug17tpe-1270.subterrat_features.synthetic_network_cell_links_v0_3_candidate`
  AS link
WHERE link.run_id = v_run_id
UNION ALL
SELECT
  link.link_class,
  link.to_cell_id,
  link.from_cell_id,
  link.metric_eligible,
  link.route_weight
FROM
  `devjam26aug17tpe-1270.subterrat_features.synthetic_network_cell_links_v0_3_candidate`
  AS link
WHERE link.run_id = v_run_id;

CREATE TEMP TABLE neighbor_support AS
SELECT
  cell.cell_id,
  COUNTIF(link.link_class = 'SYNTHETIC_SEWER_LINK' AND link.metric_eligible)
    AS eligible_sewer_neighbor_count,
  COUNTIF(link.link_class = 'GENERIC_CELL_ADJACENCY')
    AS eligible_generic_neighbor_count,
  SUM(IF(
    link.link_class = 'SYNTHETIC_SEWER_LINK' AND link.metric_eligible,
    link.route_weight,
    CAST(0 AS BIGNUMERIC)
  )) AS route_weight_denominator
FROM cells AS cell
LEFT JOIN directed_links AS link
  ON cell.cell_id = link.from_cell_id
GROUP BY cell.cell_id;

CREATE TEMP TABLE nonself_transitions AS
WITH class_allocations AS (
  SELECT
    scenario.scenario_id,
    link.from_cell_id,
    link.to_cell_id,
    IF(
      link.link_class = 'SYNTHETIC_SEWER_LINK'
        AND link.metric_eligible
        AND scenario.sewer_bucket > 0,
      scenario.sewer_bucket * IF(
        scenario.uniform_sewer_distribution,
        CAST(1 AS BIGNUMERIC)
          / CAST(support.eligible_sewer_neighbor_count AS BIGNUMERIC),
        link.route_weight / support.route_weight_denominator
      ),
      CAST(0 AS BIGNUMERIC)
    ) AS sewer_allocation_unrounded,
    IF(
      link.link_class = 'GENERIC_CELL_ADJACENCY'
        AND scenario.generic_bucket > 0,
      scenario.generic_bucket
        / CAST(support.eligible_generic_neighbor_count AS BIGNUMERIC),
      CAST(0 AS BIGNUMERIC)
    ) AS generic_allocation_unrounded
  FROM scenarios AS scenario
  CROSS JOIN directed_links AS link
  JOIN neighbor_support AS support
    ON link.from_cell_id = support.cell_id
)
SELECT
  scenario_id,
  from_cell_id,
  to_cell_id,
  ROUND(
    SUM(sewer_allocation_unrounded + generic_allocation_unrounded),
    24,
    'ROUND_HALF_EVEN'
  ) AS transition_value
FROM class_allocations
GROUP BY scenario_id, from_cell_id, to_cell_id
HAVING transition_value > 0;

CREATE TEMP TABLE self_transitions AS
SELECT
  scenario.scenario_id,
  cell.cell_id AS from_cell_id,
  cell.cell_id AS to_cell_id,
  ROUND(
    CAST(1 AS BIGNUMERIC) - COALESCE(SUM(nonself.transition_value), 0),
    24,
    'ROUND_HALF_EVEN'
  ) AS transition_value,
  COUNTIF(nonself.transition_value > 0) = 0 AS self_only_transition_row
FROM scenarios AS scenario
CROSS JOIN cells AS cell
LEFT JOIN nonself_transitions AS nonself
  ON scenario.scenario_id = nonself.scenario_id
  AND cell.cell_id = nonself.from_cell_id
GROUP BY scenario.scenario_id, cell.cell_id;

CREATE OR REPLACE TABLE
  `devjam26aug17tpe-1270.subterrat_simulations.synthetic_network_transitions_v0_3_internal_simulation`
CLUSTER BY scenario_id, from_cell_id, to_cell_id AS
SELECT
  v_run_id AS run_id,
  nonself.scenario_id,
  nonself.from_cell_id,
  nonself.to_cell_id,
  nonself.transition_value,
  FALSE AS self_transition,
  self.self_only_transition_row
FROM nonself_transitions AS nonself
JOIN self_transitions AS self
  USING (scenario_id, from_cell_id)
UNION ALL
SELECT
  v_run_id,
  scenario_id,
  from_cell_id,
  to_cell_id,
  transition_value,
  TRUE,
  self_only_transition_row
FROM self_transitions;

ASSERT (
  (
    SELECT
      COUNT(*) = COUNT(DISTINCT CONCAT(
        scenario_id, CHR(31), CAST(from_cell_id AS STRING), CHR(31),
        CAST(to_cell_id AS STRING)
      ))
      AND COUNTIF(transition_value < 0 OR transition_value > 1) = 0
    FROM
      `devjam26aug17tpe-1270.subterrat_simulations.synthetic_network_transitions_v0_3_internal_simulation`
  )
  AND (
    SELECT
      MAX(row_residual) <= CAST('0.000000000001' AS BIGNUMERIC)
    FROM (
      SELECT
        scenario_id,
        from_cell_id,
        ABS(SUM(transition_value) - CAST(1 AS BIGNUMERIC)) AS row_residual
      FROM
        `devjam26aug17tpe-1270.subterrat_simulations.synthetic_network_transitions_v0_3_internal_simulation`
      GROUP BY scenario_id, from_cell_id
    )
  )
) AS 'transition matrix is not canonical row-stochastic';

CREATE TEMP TABLE state_work AS
SELECT
  scenario.scenario_id,
  0 AS abstract_iteration,
  seed.cell_id,
  seed.stored_source_seed AS unit_mass_state
FROM scenarios AS scenario
CROSS JOIN seeds AS seed;

CREATE TEMP TABLE all_states AS SELECT * FROM state_work;

WHILE iteration_number <= 8 DO
  CREATE OR REPLACE TEMP TABLE next_state AS
  WITH propagated AS (
    SELECT
      transition.scenario_id,
      transition.to_cell_id AS cell_id,
      SUM(ROUND(
        CAST('0.75' AS BIGNUMERIC)
          * prior.unit_mass_state
          * transition.transition_value,
        30,
        'ROUND_HALF_EVEN'
      )) AS propagated_mass
    FROM state_work AS prior
    JOIN
      `devjam26aug17tpe-1270.subterrat_simulations.synthetic_network_transitions_v0_3_internal_simulation`
      AS transition
      ON prior.scenario_id = transition.scenario_id
      AND prior.cell_id = transition.from_cell_id
    GROUP BY transition.scenario_id, transition.to_cell_id
  )
  SELECT
    scenario.scenario_id,
    iteration_number AS abstract_iteration,
    seed.cell_id,
    ROUND(
      ROUND(
        CAST('0.25' AS BIGNUMERIC) * seed.stored_source_seed,
        30,
        'ROUND_HALF_EVEN'
      ) + propagated.propagated_mass,
      24,
      'ROUND_HALF_EVEN'
    ) AS unit_mass_state
  FROM scenarios AS scenario
  CROSS JOIN seeds AS seed
  JOIN propagated
    ON scenario.scenario_id = propagated.scenario_id
    AND seed.cell_id = propagated.cell_id;

  INSERT INTO all_states SELECT * FROM next_state;
  CREATE OR REPLACE TEMP TABLE state_work AS SELECT * FROM next_state;
  SET iteration_number = iteration_number + 1;
END WHILE;

CREATE TEMP TABLE display_scale AS
SELECT ROUND(MAX(unit_mass_state), 24, 'ROUND_HALF_EVEN') AS display_scale_max
FROM all_states;

CREATE TEMP TABLE state_support AS
SELECT
  state.scenario_id,
  state.abstract_iteration,
  state.cell_id,
  state.unit_mass_state,
  seed.stored_source_seed,
  scale.display_scale_max,
  sewer.sewer_attribute_index IS NOT NULL AS sewer_attribute_available,
  support.eligible_sewer_neighbor_count,
  support.eligible_generic_neighbor_count,
  self.self_only_transition_row,
  CASE
    WHEN self.self_only_transition_row THEN 'SELF_ONLY'
    WHEN scenario.generic_bucket > 0
      AND support.eligible_sewer_neighbor_count = 0
      AND support.eligible_generic_neighbor_count > 0
      THEN 'GENERIC_ADJACENCY_ONLY'
    WHEN sewer.sewer_attribute_index IS NULL THEN 'SEWER_ATTRIBUTE_MISSING'
    WHEN support.eligible_sewer_neighbor_count = 0
      THEN 'NO_ELIGIBLE_SEWER_NEIGHBOR'
    ELSE 'METRIC_SEWER_SUPPORTED'
  END AS cell_support_state
FROM all_states AS state
JOIN seeds AS seed USING (cell_id)
CROSS JOIN display_scale AS scale
LEFT JOIN sewer_attributes AS sewer USING (cell_id)
JOIN neighbor_support AS support USING (cell_id)
JOIN scenarios AS scenario USING (scenario_id)
JOIN self_transitions AS self
  ON state.scenario_id = self.scenario_id
  AND state.cell_id = self.from_cell_id;

CREATE OR REPLACE TABLE
  `devjam26aug17tpe-1270.subterrat_simulations.synthetic_network_states_v0_3_internal_simulation`
CLUSTER BY scenario_id, abstract_iteration, cell_id AS
SELECT
  v_run_id AS run_id,
  state.scenario_id,
  state.abstract_iteration,
  state.cell_id,
  state.stored_source_seed AS source_seed,
  state.unit_mass_state,
  state.display_scale_max,
  ROUND(
    state.unit_mass_state / state.display_scale_max,
    12,
    'ROUND_HALF_EVEN'
  ) AS relative_synthetic_network_state,
  state.sewer_attribute_available,
  state.eligible_sewer_neighbor_count,
  state.eligible_generic_neighbor_count,
  state.self_only_transition_row,
  state.cell_support_state,
  ARRAY(
    SELECT DISTINCT code
    FROM UNNEST(ARRAY_CONCAT(
      [
        'CELL_GRAPH_IS_NOT_TRUE_SEWER_TOPOLOGY',
        'V0_2_SEWER_METRIC_GATES_INCOMPLETE'
      ],
      IF(
        NOT state.sewer_attribute_available,
        ['SEWER_ATTRIBUTE_MISSING'],
        []
      ),
      IF(
        state.eligible_sewer_neighbor_count = 0,
        ['NO_ELIGIBLE_SEWER_NEIGHBOR'],
        []
      ),
      IF(
        state.cell_support_state = 'GENERIC_ADJACENCY_ONLY',
        ['GENERIC_ADJACENCY_ONLY_SUPPORT'],
        []
      ),
      IF(
        state.self_only_transition_row,
        ['SELF_ONLY_TRANSITION_ROW'],
        []
      )
    )) AS code
    ORDER BY code
  ) AS cell_limitation_codes
FROM state_support AS state;

ASSERT (
  SELECT
    COUNT(*) = 3420 * 3 * 9
    AND COUNT(*) = COUNT(DISTINCT CONCAT(
      scenario_id, CHR(31), CAST(abstract_iteration AS STRING), CHR(31),
      CAST(cell_id AS STRING)
    ))
    AND COUNTIF(relative_synthetic_network_state NOT BETWEEN 0 AND 1) = 0
    AND COUNT(DISTINCT display_scale_max) = 1
  FROM
    `devjam26aug17tpe-1270.subterrat_simulations.synthetic_network_states_v0_3_internal_simulation`
) AS 'canonical network state artifact is invalid';

CREATE OR REPLACE TABLE
  `devjam26aug17tpe-1270.subterrat_simulations.map_synthetic_network_cells_v0_3_internal_simulation`
CLUSTER BY scenario_id, abstract_iteration, cell_id AS
SELECT
  state.run_id,
  state.scenario_id,
  state.abstract_iteration,
  state.cell_id,
  ST_ASGEOJSON(cell.eligible_geom) AS eligible_geojson_canonical_text,
  state.relative_synthetic_network_state,
  state.cell_support_state,
  state.cell_limitation_codes
FROM
  `devjam26aug17tpe-1270.subterrat_simulations.synthetic_network_states_v0_3_internal_simulation`
  AS state
JOIN cells AS cell USING (cell_id);

CREATE OR REPLACE TABLE
  `devjam26aug17tpe-1270.subterrat_simulations.schematic_cell_links_v0_3_internal_simulation`
CLUSTER BY scenario_id, link_class, from_cell_id, to_cell_id AS
SELECT
  link.run_id,
  scenario.scenario_id,
  link.link_class,
  link.from_cell_id,
  link.to_cell_id,
  IF(link.link_class = 'SYNTHETIC_SEWER_LINK', TRUE, NULL)
    AS metric_eligible,
  from_cell.centroid_longitude_7 AS from_longitude,
  from_cell.centroid_latitude_7 AS from_latitude,
  to_cell.centroid_longitude_7 AS to_longitude,
  to_cell.centroid_latitude_7 AS to_latitude,
  link.link_limitation_codes
FROM scenarios AS scenario
CROSS JOIN
  `devjam26aug17tpe-1270.subterrat_features.synthetic_network_cell_links_v0_3_candidate`
  AS link
JOIN cells AS from_cell ON link.from_cell_id = from_cell.cell_id
JOIN cells AS to_cell ON link.to_cell_id = to_cell.cell_id
WHERE
  link.run_id = v_run_id
  AND (
    (link.link_class = 'SYNTHETIC_SEWER_LINK' AND link.metric_eligible)
    OR (
      scenario.scenario_id = 'n2_generic_cell_adjacency_sensitivity'
      AND link.link_class = 'GENERIC_CELL_ADJACENCY'
    )
  );
