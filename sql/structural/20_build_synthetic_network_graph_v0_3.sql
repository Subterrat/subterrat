-- Builds the outcome-free coarse cell-link graph for the approved v0.3
-- synthetic network redistribution challenger. This is not sewer topology,
-- flow, rat movement, risk, probability, or an operational artifact.
--
-- Required named parameters (all STRING):
--   repository_state, review_verdict, contract_hash,
--   finalized_input_manifest_hash, artifact_schema_contract_hash,
--   api_schema_contract_hash, sql_hash, code_revision,
--   cell_universe_content_hash, food_seed_content_hash,
--   pipe_geometry_content_hash, sewer_attribute_content_hash,
--   parent_v0_3_lock_content_hash

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

CREATE TEMP TABLE cells AS
SELECT
  cell_id,
  eligible_geom,
  ROUND(CAST(centroid_longitude AS BIGNUMERIC), 7, 'ROUND_HALF_EVEN')
    AS centroid_longitude_7,
  ROUND(CAST(centroid_latitude AS BIGNUMERIC), 7, 'ROUND_HALF_EVEN')
    AS centroid_latitude_7
FROM `devjam26aug17tpe-1270.subterrat_curated.analysis_cells`
WHERE
  grid_version = 'taipei_county_1140318_s2_l15_v1'
  AND eligible_area_m2 > 0
  AND eligible_geom IS NOT NULL;

ASSERT (
  SELECT COUNT(*) = 3420 AND COUNT(DISTINCT cell_id) = 3420 FROM cells
) AS 'frozen cell universe must contain 3420 unique cells';

CREATE TEMP TABLE universe AS
SELECT ST_UNION_AGG(eligible_geom) AS eligible_union FROM cells;

CREATE TEMP TABLE pipe_census AS
SELECT
  source_snapshot_id,
  source_resource_id,
  segment_id,
  is_active,
  geom_wgs84,
  evidence_state,
  TO_JSON_STRING(STRUCT(
    source_snapshot_id,
    source_resource_id,
    segment_id
  )) AS source_key
FROM
  `devjam26aug17tpe-1270.subterrat_curated.sanitary_pipe_segment_v0_2_candidate`
WHERE
  source_snapshot_id =
    '979ee9ac61c536177f4ee929afb2fcf44313023f6ae6d3f0585a7ffd26ea0911';

ASSERT (
  SELECT
    COUNT(*) = 198091
    AND COUNT(*) = COUNT(DISTINCT source_key)
  FROM pipe_census
) AS 'pipe source census identity is invalid';

CREATE TEMP TABLE traversal_candidates AS
SELECT *
FROM pipe_census
WHERE
  is_active
  AND geom_wgs84 IS NOT NULL
  AND ST_GEOMETRYTYPE(geom_wgs84) = 'ST_LineString'
  AND NOT ST_ISEMPTY(geom_wgs84);

CREATE TEMP TABLE elementary_edges AS
SELECT
  candidate.source_key,
  candidate.source_snapshot_id,
  candidate.source_resource_id,
  candidate.segment_id,
  candidate.geom_wgs84,
  edge_ordinal,
  ST_MAKELINE(
    ST_POINTN(candidate.geom_wgs84, edge_ordinal),
    ST_POINTN(candidate.geom_wgs84, edge_ordinal + 1)
  ) AS elementary_edge
FROM traversal_candidates AS candidate
CROSS JOIN UNNEST(
  GENERATE_ARRAY(1, ST_NUMPOINTS(candidate.geom_wgs84) - 1)
) AS edge_ordinal;

CREATE TEMP TABLE collapsed_sources AS
SELECT DISTINCT source_key
FROM elementary_edges
WHERE ST_LENGTH(elementary_edge) = 0;

CREATE TEMP TABLE outside_or_gapped_sources AS
SELECT candidate.source_key
FROM traversal_candidates AS candidate
CROSS JOIN universe
LEFT JOIN collapsed_sources USING (source_key)
WHERE
  collapsed_sources.source_key IS NULL
  AND NOT ST_COVEREDBY(candidate.geom_wgs84, universe.eligible_union);

CREATE TEMP TABLE admissible_edges AS
SELECT edge.*
FROM elementary_edges AS edge
LEFT JOIN collapsed_sources USING (source_key)
LEFT JOIN outside_or_gapped_sources USING (source_key)
WHERE
  collapsed_sources.source_key IS NULL
  AND outside_or_gapped_sources.source_key IS NULL;

CREATE TEMP TABLE traversal_fragments AS
WITH intersections AS (
  SELECT
    edge.source_key,
    edge.source_snapshot_id,
    edge.source_resource_id,
    edge.segment_id,
    edge.geom_wgs84,
    edge.edge_ordinal,
    edge.elementary_edge,
    cell.cell_id,
    ST_INTERSECTION(edge.elementary_edge, cell.eligible_geom) AS intersection_geom
  FROM admissible_edges AS edge
  JOIN cells AS cell
    ON ST_INTERSECTS(edge.elementary_edge, cell.eligible_geom)
),
dumped AS (
  SELECT intersection.*, fragment
  FROM intersections AS intersection
  CROSS JOIN UNNEST(ST_DUMP(intersection_geom, 1)) AS fragment
  WHERE ST_LENGTH(fragment) > 0
)
SELECT
  source_key,
  source_snapshot_id,
  source_resource_id,
  segment_id,
  geom_wgs84,
  edge_ordinal,
  cell_id,
  fragment,
  ROUND(CAST(LEAST(
    ST_LINELOCATEPOINT(elementary_edge, ST_POINTN(fragment, 1)),
    ST_LINELOCATEPOINT(
      elementary_edge,
      ST_POINTN(fragment, ST_NUMPOINTS(fragment))
    )
  ) AS BIGNUMERIC), 15, 'ROUND_HALF_EVEN') AS interval_low,
  ROUND(CAST(GREATEST(
    ST_LINELOCATEPOINT(elementary_edge, ST_POINTN(fragment, 1)),
    ST_LINELOCATEPOINT(
      elementary_edge,
      ST_POINTN(fragment, ST_NUMPOINTS(fragment))
    )
  ) AS BIGNUMERIC), 15, 'ROUND_HALF_EVEN') AS interval_high,
  ST_LENGTH(fragment) AS fragment_length_m
FROM dumped;

CREATE TEMP TABLE positive_boundary_overlap_sources AS
SELECT DISTINCT left_fragment.source_key
FROM traversal_fragments AS left_fragment
JOIN traversal_fragments AS right_fragment
  ON left_fragment.source_key = right_fragment.source_key
  AND left_fragment.edge_ordinal = right_fragment.edge_ordinal
  AND left_fragment.cell_id < right_fragment.cell_id
  AND left_fragment.interval_low
    < right_fragment.interval_high - CAST('0.000000000001' AS BIGNUMERIC)
  AND right_fragment.interval_low
    < left_fragment.interval_high - CAST('0.000000000001' AS BIGNUMERIC);

CREATE TEMP TABLE nonunique_traversal_sources AS
SELECT DISTINCT source_key
FROM traversal_fragments
GROUP BY
  source_key,
  edge_ordinal,
  interval_low,
  interval_high,
  cell_id
HAVING COUNT(*) > 1;

INSERT INTO outside_or_gapped_sources
SELECT candidate.source_key
FROM traversal_candidates AS candidate
LEFT JOIN collapsed_sources USING (source_key)
LEFT JOIN outside_or_gapped_sources USING (source_key)
LEFT JOIN (
  SELECT DISTINCT source_key FROM traversal_fragments
) AS observed USING (source_key)
WHERE
  collapsed_sources.source_key IS NULL
  AND outside_or_gapped_sources.source_key IS NULL
  AND observed.source_key IS NULL;

CREATE TEMP TABLE source_classifications AS
SELECT
  census.source_key,
  census.source_snapshot_id,
  census.source_resource_id,
  census.segment_id,
  CASE
    WHEN NOT census.is_active THEN 'SOURCE_ROW_INACTIVE'
    WHEN census.geom_wgs84 IS NULL THEN 'GEOMETRY_NULL'
    WHEN ST_GEOMETRYTYPE(census.geom_wgs84) != 'ST_LineString'
      THEN 'GEOMETRY_TYPE_UNSUPPORTED'
    WHEN ST_ISEMPTY(census.geom_wgs84)
      THEN 'GEOMETRY_EMPTY_OR_INVALID'
    WHEN collapsed.source_key IS NOT NULL THEN 'COLLAPSED_ELEMENTARY_EDGE'
    WHEN outside.source_key IS NOT NULL THEN 'OUTSIDE_OR_GAPPED_CELL_UNIVERSE'
    WHEN boundary.source_key IS NOT NULL THEN 'POSITIVE_LENGTH_BOUNDARY_OVERLAP'
    WHEN nonunique.source_key IS NOT NULL THEN 'NONUNIQUE_TRAVERSAL'
    ELSE 'ADMITTED'
  END AS terminal_classification
FROM pipe_census AS census
LEFT JOIN collapsed_sources AS collapsed USING (source_key)
LEFT JOIN outside_or_gapped_sources AS outside USING (source_key)
LEFT JOIN positive_boundary_overlap_sources AS boundary USING (source_key)
LEFT JOIN nonunique_traversal_sources AS nonunique USING (source_key);

ASSERT (
  SELECT
    COUNT(*) = 198091
    AND COUNT(DISTINCT source_key) = 198091
    AND COUNTIF(terminal_classification IS NULL) = 0
  FROM source_classifications
) AS 'every pipe census row must have one terminal classification';

CREATE TEMP TABLE admitted_sequence AS
WITH ordered AS (
  SELECT
    fragment.*,
    LAG(cell_id) OVER (
      PARTITION BY source_key
      ORDER BY
        source_snapshot_id,
        source_resource_id,
        segment_id,
        edge_ordinal,
        interval_low,
        interval_high,
        cell_id
    ) AS previous_cell_id
  FROM traversal_fragments AS fragment
  JOIN source_classifications USING (source_key)
  WHERE terminal_classification = 'ADMITTED'
)
SELECT
  *,
  ROW_NUMBER() OVER (
    PARTITION BY source_key
    ORDER BY
      source_snapshot_id,
      source_resource_id,
      segment_id,
      edge_ordinal,
      interval_low,
      interval_high,
      cell_id
  ) AS traversal_ordinal
FROM ordered
WHERE previous_cell_id IS NULL OR previous_cell_id != cell_id;

CREATE TEMP TABLE source_links AS
WITH adjacent AS (
  SELECT
    sequence.*,
    LEAD(cell_id) OVER (
      PARTITION BY source_key ORDER BY traversal_ordinal
    ) AS next_cell_id
  FROM admitted_sequence AS sequence
)
SELECT DISTINCT
  source_key,
  source_resource_id,
  LEAST(cell_id, next_cell_id) AS from_cell_id,
  GREATEST(cell_id, next_cell_id) AS to_cell_id,
  ST_LENGTH(geom_wgs84) AS source_segment_length_m
FROM adjacent
WHERE next_cell_id IS NOT NULL AND cell_id != next_cell_id;

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

CREATE TEMP TABLE sewer_links AS
SELECT
  source.from_cell_id,
  source.to_cell_id,
  from_metric.sewer_attribute_index IS NOT NULL
    AND to_metric.sewer_attribute_index IS NOT NULL AS metric_eligible,
  IF(
    from_metric.sewer_attribute_index IS NOT NULL
      AND to_metric.sewer_attribute_index IS NOT NULL,
    ROUND(
      CAST('0.25' AS BIGNUMERIC)
      + CAST('0.75' AS BIGNUMERIC)
        * (from_metric.sewer_attribute_index + to_metric.sewer_attribute_index)
        / CAST(2 AS BIGNUMERIC),
      12,
      'ROUND_HALF_EVEN'
    ),
    NULL
  ) AS route_weight,
  COUNT(DISTINCT source.source_key) AS parallel_segment_count,
  COUNT(DISTINCT source.source_resource_id) AS distinct_source_resource_count,
  ROUND(
    CAST(SUM(source.source_segment_length_m) AS BIGNUMERIC),
    6,
    'ROUND_HALF_EVEN'
  ) AS total_intersected_length_m
FROM source_links AS source
LEFT JOIN sewer_attributes AS from_metric
  ON source.from_cell_id = from_metric.cell_id
LEFT JOIN sewer_attributes AS to_metric
  ON source.to_cell_id = to_metric.cell_id
GROUP BY
  source.from_cell_id,
  source.to_cell_id,
  from_metric.sewer_attribute_index,
  to_metric.sewer_attribute_index;

CREATE TEMP TABLE generic_links AS
SELECT
  left_cell.cell_id AS from_cell_id,
  right_cell.cell_id AS to_cell_id
FROM cells AS left_cell
JOIN cells AS right_cell
  ON left_cell.cell_id < right_cell.cell_id
  AND ST_INTERSECTS(left_cell.eligible_geom, right_cell.eligible_geom)
  AND ST_LENGTH(ST_INTERSECTION(
    left_cell.eligible_geom,
    right_cell.eligible_geom
  )) > 0;

CREATE OR REPLACE TABLE
  `devjam26aug17tpe-1270.subterrat_features.synthetic_network_cell_links_v0_3_candidate`
CLUSTER BY link_class, from_cell_id, to_cell_id AS
SELECT
  v_run_id AS run_id,
  'SYNTHETIC_SEWER_LINK' AS link_class,
  from_cell_id,
  to_cell_id,
  metric_eligible,
  route_weight,
  parallel_segment_count,
  distinct_source_resource_count,
  total_intersected_length_m,
  [
    'SCHEMATIC_CENTROID_LINK_NOT_PIPE_ALIGNMENT',
    'V0_2_SEWER_METRIC_GATES_INCOMPLETE'
  ] AS link_limitation_codes,
  @finalized_input_manifest_hash AS finalized_input_manifest_hash
FROM sewer_links
UNION ALL
SELECT
  v_run_id,
  'GENERIC_CELL_ADJACENCY',
  from_cell_id,
  to_cell_id,
  CAST(NULL AS BOOL),
  CAST(NULL AS BIGNUMERIC),
  0,
  0,
  CAST('0.000000' AS BIGNUMERIC),
  [
    'GENERIC_ADJACENCY_BARRIERS_NOT_MODELED',
    'SCHEMATIC_CENTROID_LINK_NOT_PIPE_ALIGNMENT'
  ],
  @finalized_input_manifest_hash
FROM generic_links;

ASSERT (
  SELECT
    COUNT(*) = COUNT(DISTINCT CONCAT(
      link_class, CHR(31), CAST(from_cell_id AS STRING), CHR(31),
      CAST(to_cell_id AS STRING)
    ))
    AND COUNTIF(from_cell_id >= to_cell_id) = 0
    AND COUNTIF(link_class = 'SYNTHETIC_SEWER_LINK' AND metric_eligible IS NULL) = 0
    AND COUNTIF(link_class = 'GENERIC_CELL_ADJACENCY' AND metric_eligible IS NOT NULL) = 0
  FROM
    `devjam26aug17tpe-1270.subterrat_features.synthetic_network_cell_links_v0_3_candidate`
) AS 'canonical cell-link graph is invalid';

CREATE OR REPLACE TABLE
  `devjam26aug17tpe-1270.subterrat_simulations.synthetic_network_quality_v0_3_internal_simulation`
AS
WITH terminal_enum AS (
  SELECT classification
  FROM UNNEST([
    'SOURCE_ROW_INACTIVE',
    'GEOMETRY_NULL',
    'GEOMETRY_TYPE_UNSUPPORTED',
    'GEOMETRY_EMPTY_OR_INVALID',
    'COLLAPSED_ELEMENTARY_EDGE',
    'OUTSIDE_OR_GAPPED_CELL_UNIVERSE',
    'POSITIVE_LENGTH_BOUNDARY_OVERLAP',
    'NONUNIQUE_TRAVERSAL',
    'ADMITTED'
  ]) AS classification
),
terminal_quality AS (
  SELECT
    v_run_id AS run_id,
    CONCAT(
      'source_segment_terminal_classification_count', CHR(31),
      'NOT_APPLICABLE', CHR(31), CHR(31), CHR(31),
      'classification=', terminal_enum.classification
    ) AS quality_record_id,
    'source_segment_terminal_classification_count' AS metric_name,
    'NOT_APPLICABLE' AS graph_scope,
    CAST(NULL AS STRING) AS scenario_id,
    CAST(NULL AS INT64) AS abstract_iteration,
    CONCAT('classification=', terminal_enum.classification) AS dimension_key,
    COUNTIF(classification.terminal_classification = terminal_enum.classification)
      AS integer_value,
    CAST(NULL AS BIGNUMERIC) AS decimal_value,
    CAST(NULL AS STRING) AS string_value,
    CAST(NULL AS BOOL) AS pass_bool
  FROM terminal_enum
  LEFT JOIN source_classifications AS classification
    ON classification.terminal_classification = terminal_enum.classification
  GROUP BY terminal_enum.classification
),
scalar_quality AS (
  SELECT
    v_run_id,
    CONCAT(
      'endpoint_metric_missingness_excluded_link_count', CHR(31),
      'FULL_BINARY', CHR(31), CHR(31), CHR(31)
    ) AS quality_record_id,
    'endpoint_metric_missingness_excluded_link_count' AS metric_name,
    'FULL_BINARY' AS graph_scope,
    CAST(NULL AS STRING) AS scenario_id,
    CAST(NULL AS INT64) AS abstract_iteration,
    '' AS dimension_key,
    COUNTIF(NOT metric_eligible) AS integer_value,
    CAST(NULL AS BIGNUMERIC) AS decimal_value,
    CAST(NULL AS STRING) AS string_value,
    CAST(NULL AS BOOL) AS pass_bool
  FROM sewer_links
  UNION ALL
  SELECT
    v_run_id,
    CONCAT(
      'within_cell_admitted_segment_count', CHR(31),
      'FULL_BINARY', CHR(31), CHR(31), CHR(31)
    ),
    'within_cell_admitted_segment_count',
    'FULL_BINARY',
    NULL,
    NULL,
    '',
    COUNTIF(distinct_cells = 1),
    NULL,
    NULL,
    NULL
  FROM (
    SELECT source_key, COUNT(DISTINCT cell_id) AS distinct_cells
    FROM admitted_sequence
    GROUP BY source_key
  )
  UNION ALL
  SELECT
    v_run_id,
    CONCAT(
      'parallel_source_segment_duplicate_excess_total', CHR(31),
      'FULL_BINARY', CHR(31), CHR(31), CHR(31)
    ),
    'parallel_source_segment_duplicate_excess_total',
    'FULL_BINARY',
    NULL,
    NULL,
    '',
    SUM(GREATEST(parallel_segment_count - 1, 0)),
    NULL,
    NULL,
    NULL
  FROM sewer_links
  UNION ALL
  SELECT
    v_run_id,
    CONCAT(
      'internal_cell_connectivity_state', CHR(31),
      'NOT_APPLICABLE', CHR(31), CHR(31), CHR(31)
    ),
    'internal_cell_connectivity_state',
    'NOT_APPLICABLE',
    NULL,
    NULL,
    '',
    NULL,
    NULL,
    'NOT_IDENTIFIABLE_WITHOUT_ADDITIONAL_JUNCTION_MODEL',
    NULL
)
SELECT * FROM terminal_quality
UNION ALL
SELECT * FROM scalar_quality;

ASSERT (
  SELECT
    COUNTIF(metric_name = 'source_segment_terminal_classification_count') = 9
    AND SUM(IF(
      metric_name = 'source_segment_terminal_classification_count',
      integer_value,
      0
    )) = 198091
  FROM
    `devjam26aug17tpe-1270.subterrat_simulations.synthetic_network_quality_v0_3_internal_simulation`
) AS 'pipe census terminal QA is incomplete';
