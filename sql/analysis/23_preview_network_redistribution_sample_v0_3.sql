-- PARTIAL PREVIEW ONLY.
-- Uses all 3,420 frozen cells and real food/sewer metrics, but only a
-- deterministic 5,000-segment pipe sample. It is not the final graph, model,
-- hotspot map, validation, probability, risk, forecast, or operational output.

DECLARE iteration_number INT64 DEFAULT 1;

CREATE TEMP TABLE preview_cells AS
SELECT
  cell.cell_id,
  cell.eligible_geom,
  cell.centroid_longitude,
  cell.centroid_latitude,
  ROUND(CAST(cell.eligible_area_m2 AS BIGNUMERIC), 6, 'ROUND_HALF_EVEN')
    AS eligible_area_m2_6,
  ROUND(CAST(food.food_score AS BIGNUMERIC), 12, 'ROUND_HALF_EVEN')
    AS food_score_12
FROM `devjam26aug17tpe-1270.subterrat_curated.analysis_cells` AS cell
JOIN `devjam26aug17tpe-1270.subterrat_predictions.map_hotspot_cells_t0` AS food
  USING (cell_id)
WHERE
  cell.grid_version = 'taipei_county_1140318_s2_l15_v1'
  AND cell.eligible_area_m2 > 0
  AND food.freeze_id = 't0-layerwise-development-20260817-v2'
  AND food.score_semantics = 'LAYER_SCORE_NOT_PROBABILITY';

ASSERT (
  SELECT COUNT(*) = 3420 AND COUNT(DISTINCT cell_id) = 3420
  FROM preview_cells
) AS 'preview cell universe is not the frozen 3420-cell set';

CREATE TEMP TABLE preview_seeds AS
WITH raw AS (
  SELECT
    cell_id,
    ROUND(
      food_score_12 * eligible_area_m2_6,
      18,
      'ROUND_HALF_EVEN'
    ) AS stored_raw_seed
  FROM preview_cells
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
  ) AS source_seed
FROM raw
CROSS JOIN total;

CREATE TEMP TABLE preview_universe AS
SELECT ST_UNION_AGG(eligible_geom) AS eligible_union
FROM preview_cells;

CREATE TEMP TABLE preview_segments AS
WITH deterministic_candidates AS (
  SELECT
    source_snapshot_id,
    source_resource_id,
    segment_id,
    geom_wgs84,
    TO_JSON_STRING(STRUCT(
      source_snapshot_id,
      source_resource_id,
      segment_id
    )) AS source_key
  FROM
    `devjam26aug17tpe-1270.subterrat_curated.sanitary_pipe_segment_v0_2_candidate`
  WHERE
    source_snapshot_id =
      '979ee9ac61c536177f4ee929afb2fcf44313023f6ae6d3f0585a7ffd26ea0911'
    AND is_active
    AND geom_wgs84 IS NOT NULL
    AND ST_GEOMETRYTYPE(geom_wgs84) = 'ST_LineString'
    AND NOT ST_ISEMPTY(geom_wgs84)
  QUALIFY ROW_NUMBER() OVER (
    ORDER BY FARM_FINGERPRINT(CONCAT(source_resource_id, ':', segment_id))
  ) <= 7500
)
SELECT candidate.*
FROM deterministic_candidates AS candidate
CROSS JOIN preview_universe AS universe
WHERE ST_COVEREDBY(candidate.geom_wgs84, universe.eligible_union)
ORDER BY FARM_FINGERPRINT(CONCAT(
  candidate.source_resource_id,
  ':',
  candidate.segment_id
))
LIMIT 5000;

CREATE TEMP TABLE preview_edges AS
SELECT
  segment.source_key,
  segment.source_resource_id,
  segment.segment_id,
  edge_ordinal,
  ST_MAKELINE(
    ST_POINTN(segment.geom_wgs84, edge_ordinal),
    ST_POINTN(segment.geom_wgs84, edge_ordinal + 1)
  ) AS elementary_edge
FROM preview_segments AS segment
CROSS JOIN UNNEST(
  GENERATE_ARRAY(1, ST_NUMPOINTS(segment.geom_wgs84) - 1)
) AS edge_ordinal;

CREATE TEMP TABLE preview_collapsed_sources AS
SELECT DISTINCT source_key
FROM preview_edges
WHERE ST_LENGTH(elementary_edge) = 0;

CREATE TEMP TABLE preview_fragments AS
WITH intersections AS (
  SELECT
    edge.source_key,
    edge.source_resource_id,
    edge.segment_id,
    edge.edge_ordinal,
    edge.elementary_edge,
    cell.cell_id,
    ST_INTERSECTION(edge.elementary_edge, cell.eligible_geom)
      AS intersection_geom
  FROM preview_edges AS edge
  LEFT JOIN preview_collapsed_sources AS collapsed USING (source_key)
  JOIN preview_cells AS cell
    ON ST_INTERSECTS(edge.elementary_edge, cell.eligible_geom)
  WHERE collapsed.source_key IS NULL
),
dumped AS (
  SELECT intersection.*, fragment
  FROM intersections AS intersection
  CROSS JOIN UNNEST(ST_DUMP(intersection_geom, 1)) AS fragment
  WHERE ST_LENGTH(fragment) > 0
)
SELECT
  source_key,
  source_resource_id,
  segment_id,
  edge_ordinal,
  cell_id,
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
  ) AS BIGNUMERIC), 15, 'ROUND_HALF_EVEN') AS interval_high
FROM dumped;

CREATE TEMP TABLE preview_boundary_overlap_sources AS
SELECT DISTINCT left_fragment.source_key
FROM preview_fragments AS left_fragment
JOIN preview_fragments AS right_fragment
  ON left_fragment.source_key = right_fragment.source_key
  AND left_fragment.edge_ordinal = right_fragment.edge_ordinal
  AND left_fragment.cell_id < right_fragment.cell_id
  AND left_fragment.interval_low
    < right_fragment.interval_high - CAST('0.000000000001' AS BIGNUMERIC)
  AND right_fragment.interval_low
    < left_fragment.interval_high - CAST('0.000000000001' AS BIGNUMERIC);

CREATE TEMP TABLE preview_sequence AS
WITH ordered AS (
  SELECT
    fragment.*,
    LAG(cell_id) OVER (
      PARTITION BY source_key
      ORDER BY
        source_resource_id,
        segment_id,
        edge_ordinal,
        interval_low,
        interval_high,
        cell_id
    ) AS previous_cell_id
  FROM preview_fragments AS fragment
  LEFT JOIN preview_boundary_overlap_sources AS boundary USING (source_key)
  WHERE boundary.source_key IS NULL
),
deduplicated AS (
  SELECT *
  FROM ordered
  WHERE previous_cell_id IS NULL OR previous_cell_id != cell_id
)
SELECT
  *,
  ROW_NUMBER() OVER (
    PARTITION BY source_key
    ORDER BY
      source_resource_id,
      segment_id,
      edge_ordinal,
      interval_low,
      interval_high,
      cell_id
  ) AS traversal_ordinal
FROM deduplicated;

CREATE TEMP TABLE preview_source_links AS
WITH adjacent AS (
  SELECT
    sequence.*,
    LEAD(cell_id) OVER (
      PARTITION BY source_key ORDER BY traversal_ordinal
    ) AS next_cell_id
  FROM preview_sequence AS sequence
)
SELECT DISTINCT
  source_key,
  LEAST(cell_id, next_cell_id) AS from_cell_id,
  GREATEST(cell_id, next_cell_id) AS to_cell_id
FROM adjacent
WHERE next_cell_id IS NOT NULL AND cell_id != next_cell_id;

CREATE TEMP TABLE preview_sewer_attributes AS
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

CREATE TEMP TABLE preview_links AS
SELECT
  source.from_cell_id,
  source.to_cell_id,
  ROUND(
    CAST('0.25' AS BIGNUMERIC)
    + CAST('0.75' AS BIGNUMERIC)
      * (from_metric.sewer_attribute_index + to_metric.sewer_attribute_index)
      / CAST(2 AS BIGNUMERIC),
    12,
    'ROUND_HALF_EVEN'
  ) AS route_weight,
  COUNT(DISTINCT source.source_key) AS sampled_segment_count
FROM preview_source_links AS source
JOIN preview_sewer_attributes AS from_metric
  ON source.from_cell_id = from_metric.cell_id
JOIN preview_sewer_attributes AS to_metric
  ON source.to_cell_id = to_metric.cell_id
WHERE
  from_metric.sewer_attribute_index IS NOT NULL
  AND to_metric.sewer_attribute_index IS NOT NULL
GROUP BY
  source.from_cell_id,
  source.to_cell_id,
  from_metric.sewer_attribute_index,
  to_metric.sewer_attribute_index;

CREATE TEMP TABLE preview_directed_links AS
SELECT from_cell_id, to_cell_id, route_weight FROM preview_links
UNION ALL
SELECT to_cell_id, from_cell_id, route_weight FROM preview_links;

CREATE TEMP TABLE preview_neighbor_support AS
SELECT
  cell.cell_id,
  COUNT(link.to_cell_id) AS eligible_neighbor_count,
  COALESCE(SUM(link.route_weight), CAST(0 AS BIGNUMERIC))
    AS route_weight_denominator
FROM preview_cells AS cell
LEFT JOIN preview_directed_links AS link
  ON cell.cell_id = link.from_cell_id
GROUP BY cell.cell_id;

CREATE TEMP TABLE preview_nonself_transitions AS
SELECT
  link.from_cell_id,
  link.to_cell_id,
  ROUND(
    CAST('0.35' AS BIGNUMERIC)
      * link.route_weight / support.route_weight_denominator,
    24,
    'ROUND_HALF_EVEN'
  ) AS transition_value
FROM preview_directed_links AS link
JOIN preview_neighbor_support AS support
  ON link.from_cell_id = support.cell_id;

CREATE TEMP TABLE preview_self_transitions AS
SELECT
  cell.cell_id AS from_cell_id,
  cell.cell_id AS to_cell_id,
  ROUND(
    CAST(1 AS BIGNUMERIC) - COALESCE(SUM(nonself.transition_value), 0),
    24,
    'ROUND_HALF_EVEN'
  ) AS transition_value
FROM preview_cells AS cell
LEFT JOIN preview_nonself_transitions AS nonself
  ON cell.cell_id = nonself.from_cell_id
GROUP BY cell.cell_id;

CREATE TEMP TABLE preview_transitions AS
SELECT * FROM preview_nonself_transitions
UNION ALL
SELECT * FROM preview_self_transitions;

ASSERT (
  SELECT MAX(ABS(row_sum - CAST(1 AS BIGNUMERIC)))
    <= CAST('0.000000000001' AS BIGNUMERIC)
  FROM (
    SELECT from_cell_id, SUM(transition_value) AS row_sum
    FROM preview_transitions
    GROUP BY from_cell_id
  )
) AS 'preview transition rows do not conserve mass';

CREATE TEMP TABLE preview_state_work AS
SELECT 0 AS abstract_iteration, cell_id, source_seed AS unit_mass_state
FROM preview_seeds;
CREATE TEMP TABLE preview_all_states AS SELECT * FROM preview_state_work;

WHILE iteration_number <= 2 DO
  CREATE OR REPLACE TEMP TABLE preview_next_state AS
  WITH propagated AS (
    SELECT
      transition.to_cell_id AS cell_id,
      SUM(ROUND(
        CAST('0.75' AS BIGNUMERIC)
          * prior.unit_mass_state
          * transition.transition_value,
        30,
        'ROUND_HALF_EVEN'
      )) AS propagated_mass
    FROM preview_state_work AS prior
    JOIN preview_transitions AS transition
      ON prior.cell_id = transition.from_cell_id
    GROUP BY transition.to_cell_id
  )
  SELECT
    iteration_number AS abstract_iteration,
    seed.cell_id,
    ROUND(
      ROUND(
        CAST('0.25' AS BIGNUMERIC) * seed.source_seed,
        30,
        'ROUND_HALF_EVEN'
      ) + propagated.propagated_mass,
      24,
      'ROUND_HALF_EVEN'
    ) AS unit_mass_state
  FROM preview_seeds AS seed
  JOIN propagated USING (cell_id);

  INSERT INTO preview_all_states SELECT * FROM preview_next_state;
  CREATE OR REPLACE TEMP TABLE preview_state_work AS
  SELECT * FROM preview_next_state;
  SET iteration_number = iteration_number + 1;
END WHILE;

CREATE TEMP TABLE preview_state_pivot AS
SELECT
  cell_id,
  MAX(IF(abstract_iteration = 0, unit_mass_state, NULL)) AS state_0,
  MAX(IF(abstract_iteration = 1, unit_mass_state, NULL)) AS state_1,
  MAX(IF(abstract_iteration = 2, unit_mass_state, NULL)) AS state_2
FROM preview_all_states
GROUP BY cell_id;

CREATE TEMP TABLE preview_metadata AS
SELECT
  (SELECT COUNT(*) FROM preview_segments) AS sampled_source_segments,
  (SELECT COUNT(DISTINCT source_key) FROM preview_collapsed_sources)
    AS collapsed_sampled_segments,
  (SELECT COUNT(DISTINCT source_key) FROM preview_boundary_overlap_sources)
    AS boundary_overlap_sampled_segments,
  (SELECT COUNT(*) FROM (
    SELECT DISTINCT from_cell_id, to_cell_id FROM preview_source_links
  )) AS sampled_binary_links,
  (SELECT COUNT(*) FROM preview_links) AS metric_eligible_sampled_links,
  (SELECT COUNTIF(eligible_neighbor_count > 0) FROM preview_neighbor_support)
    AS cells_with_sampled_metric_links,
  (SELECT ROUND(SUM(unit_mass_state), 24, 'ROUND_HALF_EVEN')
   FROM preview_all_states WHERE abstract_iteration = 0) AS state_mass_0,
  (SELECT ROUND(SUM(unit_mass_state), 24, 'ROUND_HALF_EVEN')
   FROM preview_all_states WHERE abstract_iteration = 1) AS state_mass_1,
  (SELECT ROUND(SUM(unit_mass_state), 24, 'ROUND_HALF_EVEN')
   FROM preview_all_states WHERE abstract_iteration = 2) AS state_mass_2,
  (SELECT ROUND(MAX(unit_mass_state), 24, 'ROUND_HALF_EVEN')
   FROM preview_all_states) AS preview_display_scale_max;

SELECT
  metadata.*,
  cell.cell_id,
  cell.centroid_longitude,
  cell.centroid_latitude,
  sewer.sewer_attribute_index,
  support.eligible_neighbor_count,
  state.state_0 AS source_seed,
  state.state_1,
  state.state_2,
  ROUND(
    state.state_2 / metadata.preview_display_scale_max,
    12,
    'ROUND_HALF_EVEN'
  ) AS relative_preview_state_2,
  ROUND(state.state_2 - state.state_0, 24, 'ROUND_HALF_EVEN')
    AS absolute_state_change_at_2
FROM preview_state_pivot AS state
JOIN preview_cells AS cell USING (cell_id)
LEFT JOIN preview_sewer_attributes AS sewer USING (cell_id)
JOIN preview_neighbor_support AS support USING (cell_id)
CROSS JOIN preview_metadata AS metadata
ORDER BY ABS(state.state_2 - state.state_0) DESC, cell.cell_id
LIMIT 30;
