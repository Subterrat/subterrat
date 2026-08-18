-- Finalizes the normative graph/component/numerical quality registry for the
-- internal synthetic network redistribution challenger. Required named
-- parameters are identical to SQL 20 and 21.

ASSERT (
  @repository_state = 'COMMITTED_SOURCE'
  AND @review_verdict = 'APPROVE_FOR_INTERNAL_IMPLEMENTATION'
  AND REGEXP_CONTAINS(@contract_hash, r'^[0-9a-f]{64}$')
  AND REGEXP_CONTAINS(@finalized_input_manifest_hash, r'^[0-9a-f]{64}$')
  AND REGEXP_CONTAINS(@artifact_schema_contract_hash, r'^[0-9a-f]{64}$')
  AND REGEXP_CONTAINS(@api_schema_contract_hash, r'^[0-9a-f]{64}$')
  AND REGEXP_CONTAINS(@sql_hash, r'^[0-9a-f]{64}$')
  AND REGEXP_CONTAINS(@code_revision, r'^[0-9a-f]{40}$')
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
DECLARE changed_count INT64 DEFAULT 1;
DECLARE component_iteration INT64 DEFAULT 0;

CREATE TEMP TABLE existing_quality AS
SELECT *
FROM
  `devjam26aug17tpe-1270.subterrat_simulations.synthetic_network_quality_v0_3_internal_simulation`
WHERE run_id = v_run_id;

CREATE TEMP TABLE cells AS
SELECT cell_id
FROM `devjam26aug17tpe-1270.subterrat_curated.analysis_cells`
WHERE
  grid_version = 'taipei_county_1140318_s2_l15_v1'
  AND eligible_area_m2 > 0
  AND eligible_geom IS NOT NULL;

CREATE TEMP TABLE graph_edges AS
SELECT
  'FULL_BINARY' AS graph_scope,
  from_cell_id,
  to_cell_id
FROM
  `devjam26aug17tpe-1270.subterrat_features.synthetic_network_cell_links_v0_3_candidate`
WHERE run_id = v_run_id AND link_class = 'SYNTHETIC_SEWER_LINK'
UNION ALL
SELECT
  'METRIC_ELIGIBLE',
  from_cell_id,
  to_cell_id
FROM
  `devjam26aug17tpe-1270.subterrat_features.synthetic_network_cell_links_v0_3_candidate`
WHERE
  run_id = v_run_id
  AND link_class = 'SYNTHETIC_SEWER_LINK'
  AND metric_eligible
UNION ALL
SELECT
  'N2_UNION',
  from_cell_id,
  to_cell_id
FROM
  `devjam26aug17tpe-1270.subterrat_features.synthetic_network_cell_links_v0_3_candidate`
WHERE
  run_id = v_run_id
  AND (
    (link_class = 'SYNTHETIC_SEWER_LINK' AND metric_eligible)
    OR link_class = 'GENERIC_CELL_ADJACENCY'
  );

CREATE TEMP TABLE directed_graph_edges AS
SELECT * FROM graph_edges
UNION ALL
SELECT graph_scope, to_cell_id, from_cell_id FROM graph_edges;

CREATE TEMP TABLE component_labels AS
SELECT
  graph_scope,
  cell.cell_id,
  cell.cell_id AS component_id
FROM cells AS cell
CROSS JOIN UNNEST(['FULL_BINARY', 'METRIC_ELIGIBLE', 'N2_UNION']) AS graph_scope;

WHILE changed_count > 0 AND component_iteration < 3420 DO
  CREATE OR REPLACE TEMP TABLE next_component_labels AS
  SELECT
    current.graph_scope,
    current.cell_id,
    LEAST(
      current.component_id,
      COALESCE(MIN(neighbor.component_id), current.component_id)
    ) AS component_id
  FROM component_labels AS current
  LEFT JOIN directed_graph_edges AS edge
    ON current.graph_scope = edge.graph_scope
    AND current.cell_id = edge.from_cell_id
  LEFT JOIN component_labels AS neighbor
    ON edge.graph_scope = neighbor.graph_scope
    AND edge.to_cell_id = neighbor.cell_id
  GROUP BY current.graph_scope, current.cell_id, current.component_id;

  SET changed_count = (
    SELECT COUNTIF(current.component_id != next.component_id)
    FROM component_labels AS current
    JOIN next_component_labels AS next
      USING (graph_scope, cell_id)
  );
  CREATE OR REPLACE TEMP TABLE component_labels AS
  SELECT * FROM next_component_labels;
  SET component_iteration = component_iteration + 1;
END WHILE;

ASSERT changed_count = 0
  AS 'component label propagation did not converge within 3420 iterations';

CREATE TEMP TABLE source_seed AS
SELECT cell_id, ANY_VALUE(source_seed) AS source_seed
FROM
  `devjam26aug17tpe-1270.subterrat_simulations.synthetic_network_states_v0_3_internal_simulation`
WHERE run_id = v_run_id AND abstract_iteration = 0
GROUP BY cell_id;

CREATE TEMP TABLE graph_quality AS
WITH graph_scopes AS (
  SELECT graph_scope
  FROM UNNEST(['FULL_BINARY', 'METRIC_ELIGIBLE', 'N2_UNION']) AS graph_scope
),
link_counts AS (
  SELECT graph_scope, COUNT(*) AS link_count
  FROM graph_edges
  GROUP BY graph_scope
),
degrees AS (
  SELECT
    label.graph_scope,
    label.cell_id,
    COUNT(DISTINCT edge.to_cell_id) AS neighbor_degree
  FROM component_labels AS label
  LEFT JOIN directed_graph_edges AS edge
    ON label.graph_scope = edge.graph_scope
    AND label.cell_id = edge.from_cell_id
  GROUP BY label.graph_scope, label.cell_id
),
component_sizes AS (
  SELECT graph_scope, component_id, COUNT(*) AS cell_count
  FROM component_labels
  GROUP BY graph_scope, component_id
),
component_mass AS (
  SELECT
    label.graph_scope,
    label.component_id,
    ROUND(SUM(seed.source_seed), 30, 'ROUND_HALF_EVEN') AS source_mass
  FROM component_labels AS label
  JOIN source_seed AS seed USING (cell_id)
  GROUP BY label.graph_scope, label.component_id
)
SELECT
  v_run_id AS run_id,
  CONCAT('graph_link_count', CHR(31), scope.graph_scope, CHR(31), CHR(31), CHR(31))
    AS quality_record_id,
  'graph_link_count' AS metric_name,
  scope.graph_scope,
  CAST(NULL AS STRING) AS scenario_id,
  CAST(NULL AS INT64) AS abstract_iteration,
  '' AS dimension_key,
  COALESCE(link_count.link_count, 0) AS integer_value,
  CAST(NULL AS BIGNUMERIC) AS decimal_value,
  CAST(NULL AS STRING) AS string_value,
  CAST(NULL AS BOOL) AS pass_bool
FROM graph_scopes AS scope
LEFT JOIN link_counts AS link_count USING (graph_scope)
UNION ALL
SELECT
  v_run_id,
  CONCAT(
    'neighbor_degree_by_cell', CHR(31), graph_scope, CHR(31), CHR(31),
    CHR(31), 'cell_id=', CAST(cell_id AS STRING)
  ),
  'neighbor_degree_by_cell',
  graph_scope,
  NULL,
  NULL,
  CONCAT('cell_id=', CAST(cell_id AS STRING)),
  neighbor_degree,
  NULL,
  NULL,
  NULL
FROM degrees
UNION ALL
SELECT
  v_run_id,
  CONCAT('connected_component_count', CHR(31), graph_scope, CHR(31), CHR(31), CHR(31)),
  'connected_component_count',
  graph_scope,
  NULL,
  NULL,
  '',
  COUNT(*),
  NULL,
  NULL,
  NULL
FROM component_sizes
GROUP BY graph_scope
UNION ALL
SELECT
  v_run_id,
  CONCAT('largest_component_cell_share', CHR(31), graph_scope, CHR(31), CHR(31), CHR(31)),
  'largest_component_cell_share',
  graph_scope,
  NULL,
  NULL,
  '',
  NULL,
  ROUND(
    CAST(MAX(cell_count) AS BIGNUMERIC) / CAST(3420 AS BIGNUMERIC),
    30,
    'ROUND_HALF_EVEN'
  ),
  NULL,
  NULL
FROM component_sizes
GROUP BY graph_scope
UNION ALL
SELECT
  v_run_id,
  CONCAT(
    'source_mass_by_component', CHR(31), graph_scope, CHR(31), CHR(31),
    CHR(31), 'component_id=', CAST(component_id AS STRING)
  ),
  'source_mass_by_component',
  graph_scope,
  NULL,
  NULL,
  CONCAT('component_id=', CAST(component_id AS STRING)),
  NULL,
  source_mass,
  NULL,
  NULL
FROM component_mass;

CREATE TEMP TABLE transition_quality AS
SELECT
  v_run_id AS run_id,
  CONCAT(
    'transition_row_sum_max_absolute_residual', CHR(31),
    'NOT_APPLICABLE', CHR(31), scenario_id, CHR(31), CHR(31)
  ) AS quality_record_id,
  'transition_row_sum_max_absolute_residual' AS metric_name,
  'NOT_APPLICABLE' AS graph_scope,
  scenario_id,
  CAST(NULL AS INT64) AS abstract_iteration,
  '' AS dimension_key,
  CAST(NULL AS INT64) AS integer_value,
  ROUND(MAX(row_residual), 30, 'ROUND_HALF_EVEN') AS decimal_value,
  CAST(NULL AS STRING) AS string_value,
  CAST(NULL AS BOOL) AS pass_bool
FROM (
  SELECT
    scenario_id,
    from_cell_id,
    ABS(SUM(transition_value) - CAST(1 AS BIGNUMERIC)) AS row_residual
  FROM
    `devjam26aug17tpe-1270.subterrat_simulations.synthetic_network_transitions_v0_3_internal_simulation`
  WHERE run_id = v_run_id
  GROUP BY scenario_id, from_cell_id
)
GROUP BY scenario_id;

CREATE TEMP TABLE state_quality AS
WITH state_mass AS (
  SELECT
    scenario_id,
    abstract_iteration,
    ROUND(
      ABS(SUM(unit_mass_state) - CAST(1 AS BIGNUMERIC)),
      30,
      'ROUND_HALF_EVEN'
    ) AS residual
  FROM
    `devjam26aug17tpe-1270.subterrat_simulations.synthetic_network_states_v0_3_internal_simulation`
  WHERE run_id = v_run_id
  GROUP BY scenario_id, abstract_iteration
),
recomputed AS (
  SELECT
    current.scenario_id,
    current.abstract_iteration,
    current.cell_id,
    current.unit_mass_state,
    ROUND(
      ROUND(
        CAST('0.25' AS BIGNUMERIC) * current.source_seed,
        30,
        'ROUND_HALF_EVEN'
      )
      + SUM(ROUND(
        CAST('0.75' AS BIGNUMERIC)
          * prior.unit_mass_state
          * transition.transition_value,
        30,
        'ROUND_HALF_EVEN'
      )),
      24,
      'ROUND_HALF_EVEN'
    ) AS expected_state
  FROM
    `devjam26aug17tpe-1270.subterrat_simulations.synthetic_network_states_v0_3_internal_simulation`
    AS current
  JOIN
    `devjam26aug17tpe-1270.subterrat_simulations.synthetic_network_transitions_v0_3_internal_simulation`
    AS transition
    ON current.scenario_id = transition.scenario_id
    AND current.cell_id = transition.to_cell_id
  JOIN
    `devjam26aug17tpe-1270.subterrat_simulations.synthetic_network_states_v0_3_internal_simulation`
    AS prior
    ON transition.scenario_id = prior.scenario_id
    AND transition.from_cell_id = prior.cell_id
    AND prior.abstract_iteration = current.abstract_iteration - 1
  WHERE
    current.run_id = v_run_id
    AND transition.run_id = v_run_id
    AND prior.run_id = v_run_id
    AND current.abstract_iteration BETWEEN 1 AND 8
  GROUP BY
    current.scenario_id,
    current.abstract_iteration,
    current.cell_id,
    current.unit_mass_state,
    current.source_seed
),
recurrence AS (
  SELECT
    scenario_id,
    abstract_iteration,
    ROUND(
      MAX(ABS(unit_mass_state - expected_state)),
      30,
      'ROUND_HALF_EVEN'
    ) AS residual
  FROM recomputed
  GROUP BY scenario_id, abstract_iteration
)
SELECT
  v_run_id AS run_id,
  CONCAT(
    'state_mass_absolute_residual', CHR(31), 'NOT_APPLICABLE', CHR(31),
    scenario_id, CHR(31), FORMAT('%02d', abstract_iteration), CHR(31)
  ) AS quality_record_id,
  'state_mass_absolute_residual' AS metric_name,
  'NOT_APPLICABLE' AS graph_scope,
  scenario_id,
  abstract_iteration,
  '' AS dimension_key,
  CAST(NULL AS INT64) AS integer_value,
  residual AS decimal_value,
  CAST(NULL AS STRING) AS string_value,
  CAST(NULL AS BOOL) AS pass_bool
FROM state_mass
UNION ALL
SELECT
  v_run_id,
  CONCAT(
    'recurrence_max_absolute_residual', CHR(31), 'NOT_APPLICABLE', CHR(31),
    scenario_id, CHR(31), FORMAT('%02d', abstract_iteration), CHR(31)
  ),
  'recurrence_max_absolute_residual',
  'NOT_APPLICABLE',
  scenario_id,
  abstract_iteration,
  '',
  NULL,
  residual,
  NULL,
  NULL
FROM recurrence;

CREATE TEMP TABLE self_only_quality AS
SELECT
  v_run_id AS run_id,
  CONCAT(
    'self_only_source_mass', CHR(31), 'NOT_APPLICABLE', CHR(31),
    transition.scenario_id, CHR(31), CHR(31)
  ) AS quality_record_id,
  'self_only_source_mass' AS metric_name,
  'NOT_APPLICABLE' AS graph_scope,
  transition.scenario_id,
  CAST(NULL AS INT64) AS abstract_iteration,
  '' AS dimension_key,
  CAST(NULL AS INT64) AS integer_value,
  ROUND(SUM(IF(
    transition.self_only_transition_row,
    seed.source_seed,
    CAST(0 AS BIGNUMERIC)
  )), 30, 'ROUND_HALF_EVEN') AS decimal_value,
  CAST(NULL AS STRING) AS string_value,
  CAST(NULL AS BOOL) AS pass_bool
FROM (
  SELECT DISTINCT scenario_id, from_cell_id, self_only_transition_row
  FROM
    `devjam26aug17tpe-1270.subterrat_simulations.synthetic_network_transitions_v0_3_internal_simulation`
  WHERE run_id = v_run_id
) AS transition
JOIN source_seed AS seed ON transition.from_cell_id = seed.cell_id
GROUP BY transition.scenario_id;

CREATE TEMP TABLE comparator_quality AS
WITH scenario_edges AS (
  SELECT
    scenario_id,
    link.from_cell_id,
    link.to_cell_id
  FROM UNNEST([
    'n0_uniform_sewer_link_comparator',
    'n1_metric_weighted_sewer_links'
  ]) AS scenario_id
  CROSS JOIN
    `devjam26aug17tpe-1270.subterrat_features.synthetic_network_cell_links_v0_3_candidate`
    AS link
  WHERE
    link.run_id = v_run_id
    AND link.link_class = 'SYNTHETIC_SEWER_LINK'
    AND link.metric_eligible
),
edge_hashes AS (
  SELECT
    scenario_id,
    LOWER(TO_HEX(SHA256(CAST(STRING_AGG(
      CONCAT(CAST(from_cell_id AS STRING), CHR(31), CAST(to_cell_id AS STRING)),
      CHR(10) ORDER BY from_cell_id, to_cell_id
    ) AS BYTES)))) AS edge_hash
  FROM scenario_edges
  GROUP BY scenario_id
)
SELECT
  v_run_id AS run_id,
  CONCAT(
    'n0_n1_metric_eligible_edge_set_hash_equal', CHR(31),
    'METRIC_ELIGIBLE', CHR(31), CHR(31), CHR(31)
  ) AS quality_record_id,
  'n0_n1_metric_eligible_edge_set_hash_equal' AS metric_name,
  'METRIC_ELIGIBLE' AS graph_scope,
  CAST(NULL AS STRING) AS scenario_id,
  CAST(NULL AS INT64) AS abstract_iteration,
  '' AS dimension_key,
  CAST(NULL AS INT64) AS integer_value,
  CAST(NULL AS BIGNUMERIC) AS decimal_value,
  CAST(NULL AS STRING) AS string_value,
  COUNT(*) = 2 AND COUNT(DISTINCT edge_hash) = 1 AS pass_bool
FROM edge_hashes;

CREATE OR REPLACE TABLE
  `devjam26aug17tpe-1270.subterrat_simulations.synthetic_network_quality_v0_3_internal_simulation`
CLUSTER BY metric_name, graph_scope, scenario_id AS
SELECT * FROM existing_quality
UNION ALL SELECT * FROM graph_quality
UNION ALL SELECT * FROM transition_quality
UNION ALL SELECT * FROM state_quality
UNION ALL SELECT * FROM self_only_quality
UNION ALL SELECT * FROM comparator_quality;

ASSERT (
  SELECT
    COUNT(*) = COUNT(DISTINCT quality_record_id)
    AND COUNTIF(
      CAST(integer_value IS NOT NULL AS INT64)
      + CAST(decimal_value IS NOT NULL AS INT64)
      + CAST(string_value IS NOT NULL AS INT64)
      + CAST(pass_bool IS NOT NULL AS INT64) != 1
    ) = 0
    AND COUNTIF(metric_name = 'neighbor_degree_by_cell') = 10260
    AND COUNTIF(metric_name = 'state_mass_absolute_residual') = 27
    AND COUNTIF(metric_name = 'recurrence_max_absolute_residual') = 24
  FROM
    `devjam26aug17tpe-1270.subterrat_simulations.synthetic_network_quality_v0_3_internal_simulation`
) AS 'normative quality registry is incomplete or nonunique';
