-- READ-ONLY V0.3 COMPOSITE PREVIEW ONLY.
--
-- Uses the frozen v0.1 food layer, the v0.2 five-metric complete-case sewer
-- index, and the already materialized 150 m urban-renewal administrative-site
-- component. All derived objects are temporary. This query does not read Rat
-- Radar and does not create the locked v0.3 scenario or serving tables.
--
-- The equal 1/3 group weights are a preregistered, outcome-blinded assumption.
-- Output values are ordinal internal-simulation indices, not probabilities,
-- risks, forecasts, observed rat activity, or operational recommendations.

CREATE TEMP TABLE preview_components AS
WITH
cells AS (
  SELECT
    grid_version,
    cell_id,
    cell_token,
    eligible_area_m2,
    centroid_longitude,
    centroid_latitude
  FROM `devjam26aug17tpe-1270.subterrat_curated.analysis_cells`
  WHERE grid_version = 'taipei_county_1140318_s2_l15_v1'
),
v0_1 AS (
  SELECT
    cell_id,
    food_score,
    sewer_score AS sewer_system_type_score
  FROM `devjam26aug17tpe-1270.subterrat_predictions.map_hotspot_cells_t0`
  WHERE
    freeze_id = 't0-layerwise-development-20260817-v2'
    AND score_semantics = 'LAYER_SCORE_NOT_PROBABILITY'
),
sewer_metric_pivot AS (
  SELECT
    cell_id,
    COUNT(DISTINCT variant_id) AS metric_row_count,
    COUNTIF(diagnostic_percentile IS NOT NULL) AS available_metric_count,
    MAX(IF(variant_id = 'sewer_system_type', diagnostic_percentile, NULL))
      AS sewer_system_type,
    MAX(IF(variant_id = 'surface_elevation', diagnostic_percentile, NULL))
      AS surface_elevation,
    MAX(IF(
      variant_id = 'connected_pipe_diameter',
      diagnostic_percentile,
      NULL
    )) AS connected_pipe_diameter,
    MAX(IF(
      variant_id = 'connected_pipe_depth',
      diagnostic_percentile,
      NULL
    )) AS connected_pipe_depth,
    MAX(IF(
      variant_id = 'connected_pipe_age',
      diagnostic_percentile,
      NULL
    )) AS connected_pipe_age
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
),
sewer_composite AS (
  SELECT
    cell_id,
    IF(
      metric_row_count = 5 AND available_metric_count = 5,
      (
        sewer_system_type
        + surface_elevation
        + connected_pipe_diameter
        + connected_pipe_depth
        + connected_pipe_age
      ) / 5,
      NULL
    ) AS sewer_attribute_index
  FROM sewer_metric_pivot
),
renewal AS (
  SELECT
    cell_id,
    admin_site_count,
    admin_site_empirical_percentile
      AS approved_rebuilding_admin_site_r150
  FROM
    `devjam26aug17tpe-1270.subterrat_features.urban_renewal_admin_site_metrics_v0_3_internal_simulation`
  WHERE
    source_snapshot_id =
      'f31369ef4f27e6028db450051550e52f45b43f3f4e8f723ae9c50ac4ff0b1f6e'
    AND analysis_window_m = 150
    AND analysis_window_role = 'PREREGISTERED_PRIMARY'
    AND use_state = 'INTERNAL_SIMULATION_ONLY'
    AND evidence_state = 'NO_TRUSTED_RESULT'
)
SELECT
  cells.*,
  v0_1.food_score,
  v0_1.sewer_system_type_score,
  sewer_composite.sewer_attribute_index,
  renewal.admin_site_count AS renewal_admin_site_count_r150,
  renewal.approved_rebuilding_admin_site_r150,
  IF(
    v0_1.food_score IS NOT NULL
      AND sewer_composite.sewer_attribute_index IS NOT NULL
      AND renewal.approved_rebuilding_admin_site_r150 IS NOT NULL,
    (
      v0_1.food_score
      + sewer_composite.sewer_attribute_index
      + renewal.approved_rebuilding_admin_site_r150
    ) / 3,
    NULL
  ) AS v0_3_equal_group_index_r150
FROM cells
LEFT JOIN v0_1 USING (cell_id)
LEFT JOIN sewer_composite USING (cell_id)
LEFT JOIN renewal USING (cell_id);

ASSERT (
  SELECT
    COUNT(*) = 3420
    AND COUNT(*) = COUNT(DISTINCT cell_id)
    AND COUNTIF(food_score IS NOT NULL) = 3420
    AND COUNTIF(sewer_system_type_score IS NOT NULL) = 1801
    AND COUNTIF(sewer_attribute_index IS NOT NULL) = 1589
    AND COUNTIF(approved_rebuilding_admin_site_r150 IS NOT NULL) = 3420
    AND COUNTIF(v0_3_equal_group_index_r150 IS NOT NULL) = 1589
    AND COUNTIF(
      v0_3_equal_group_index_r150 IS NOT NULL
      AND (
        food_score IS NULL
        OR sewer_attribute_index IS NULL
        OR approved_rebuilding_admin_site_r150 IS NULL
      )
    ) = 0
    AND COUNTIF(v0_3_equal_group_index_r150 NOT BETWEEN 0 AND 1) = 0
  FROM preview_components
) AS 'v0.3 preview component identity, coverage, or score range is invalid';

CREATE TEMP TABLE preview_variant_rows AS
SELECT
  component.grid_version,
  component.cell_id,
  component.cell_token,
  component.eligible_area_m2,
  component.centroid_longitude,
  component.centroid_latitude,
  variant.variant_id,
  variant.simulation_index
FROM preview_components AS component
CROSS JOIN UNNEST([
  STRUCT(
    'food_market_only_v0_1' AS variant_id,
    food_score AS simulation_index
  ),
  STRUCT(
    'sewer_system_type_only_v0_1' AS variant_id,
    sewer_system_type_score AS simulation_index
  ),
  STRUCT(
    'sewer_attribute_index_v0_2_complete_case' AS variant_id,
    sewer_attribute_index AS simulation_index
  ),
  STRUCT(
    'approved_rebuilding_admin_site_cell_footprint_buffer_150m'
      AS variant_id,
    approved_rebuilding_admin_site_r150 AS simulation_index
  ),
  STRUCT(
    'v0_3_equal_group_internal_simulation_r150' AS variant_id,
    v0_3_equal_group_index_r150 AS simulation_index
  )
]) AS variant;

CREATE TEMP TABLE preview_area_ranked AS
SELECT
  *,
  SUM(IF(simulation_index IS NULL, 0, eligible_area_m2)) OVER (
    PARTITION BY variant_id
    ORDER BY simulation_index DESC NULLS LAST, cell_id
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  ) AS cumulative_scored_area_m2,
  SUM(eligible_area_m2) OVER (PARTITION BY variant_id) AS total_city_area_m2
FROM preview_variant_rows;

CREATE TEMP TABLE preview_thresholds AS
SELECT
  variant_id,
  MIN(simulation_index) AS threshold_index
FROM preview_area_ranked
WHERE
  simulation_index IS NOT NULL
  AND cumulative_scored_area_m2 - eligible_area_m2
    < total_city_area_m2 * 0.10
GROUP BY variant_id;

CREATE TEMP TABLE preview_score_ranks AS
SELECT
  variant_id,
  cell_id,
  PERCENT_RANK() OVER (
    PARTITION BY variant_id
    ORDER BY simulation_index
  ) AS rank_within_scoreable_support
FROM preview_area_ranked
WHERE simulation_index IS NOT NULL;

CREATE TEMP TABLE preview_ranked AS
SELECT
  area_ranked.*,
  score_ranks.rank_within_scoreable_support,
  area_ranked.simulation_index IS NOT NULL
    AND area_ranked.simulation_index >= thresholds.threshold_index
    AS selected_scenario_area_flag,
  thresholds.threshold_index
FROM preview_area_ranked AS area_ranked
LEFT JOIN preview_thresholds AS thresholds USING (variant_id)
LEFT JOIN preview_score_ranks AS score_ranks USING (variant_id, cell_id);

ASSERT (
  SELECT
    COUNT(*) = 3420 * 5
    AND COUNT(*) = COUNT(DISTINCT CONCAT(
      variant_id,
      ':',
      CAST(cell_id AS STRING)
    ))
    AND COUNT(DISTINCT variant_id) = 5
    AND COUNTIF(simulation_index NOT BETWEEN 0 AND 1) = 0
    AND COUNTIF(
      selected_scenario_area_flag AND simulation_index IS NULL
    ) = 0
  FROM preview_ranked
) AS 'v0.3 preview ranking or selection output is invalid';

CREATE TEMP TABLE preview_pair_specs AS
SELECT *
FROM UNNEST([
  STRUCT(
    'sewer_system_type_only_v0_1' AS left_variant,
    'food_market_only_v0_1' AS right_variant
  ),
  STRUCT(
    'sewer_attribute_index_v0_2_complete_case' AS left_variant,
    'food_market_only_v0_1' AS right_variant
  ),
  STRUCT(
    'sewer_attribute_index_v0_2_complete_case' AS left_variant,
    'sewer_system_type_only_v0_1' AS right_variant
  ),
  STRUCT(
    'approved_rebuilding_admin_site_cell_footprint_buffer_150m'
      AS left_variant,
    'food_market_only_v0_1' AS right_variant
  ),
  STRUCT(
    'v0_3_equal_group_internal_simulation_r150' AS left_variant,
    'food_market_only_v0_1' AS right_variant
  ),
  STRUCT(
    'v0_3_equal_group_internal_simulation_r150' AS left_variant,
    'sewer_attribute_index_v0_2_complete_case' AS right_variant
  ),
  STRUCT(
    'v0_3_equal_group_internal_simulation_r150' AS left_variant,
    'approved_rebuilding_admin_site_cell_footprint_buffer_150m'
      AS right_variant
  )
]);

CREATE TEMP TABLE preview_pairwise AS
SELECT
  pair.left_variant,
  pair.right_variant,
  COUNTIF(
    left_map.simulation_index IS NOT NULL
    AND right_map.simulation_index IS NOT NULL
  ) AS common_scored_cells,
  CORR(
    IF(
      left_map.simulation_index IS NOT NULL
        AND right_map.simulation_index IS NOT NULL,
      left_map.simulation_index,
      NULL
    ),
    IF(
      left_map.simulation_index IS NOT NULL
        AND right_map.simulation_index IS NOT NULL,
      right_map.simulation_index,
      NULL
    )
  ) AS score_correlation_on_common_support,
  SAFE_DIVIDE(
    SUM(IF(
      left_map.selected_scenario_area_flag
        AND right_map.selected_scenario_area_flag,
      left_map.eligible_area_m2,
      0
    )),
    SUM(IF(
      left_map.selected_scenario_area_flag
        OR right_map.selected_scenario_area_flag,
      left_map.eligible_area_m2,
      0
    ))
  ) AS selected_area_jaccard
FROM preview_pair_specs AS pair
JOIN preview_ranked AS left_map
  ON left_map.variant_id = pair.left_variant
JOIN preview_ranked AS right_map
  ON right_map.variant_id = pair.right_variant
  AND right_map.cell_id = left_map.cell_id
GROUP BY pair.left_variant, pair.right_variant;

CREATE TEMP TABLE preview_variant_summary AS
SELECT
  variant_id,
  COUNTIF(simulation_index IS NOT NULL) AS scoreable_cells,
  SAFE_DIVIDE(
    SUM(IF(simulation_index IS NOT NULL, eligible_area_m2, 0)),
    ANY_VALUE(total_city_area_m2)
  ) AS scoreable_area_share,
  AVG(simulation_index) AS mean_index,
  STDDEV_POP(simulation_index) AS standard_deviation_index,
  threshold_index,
  COUNTIF(selected_scenario_area_flag) AS selected_cells,
  SAFE_DIVIDE(
    SUM(IF(selected_scenario_area_flag, eligible_area_m2, 0)),
    ANY_VALUE(total_city_area_m2)
  ) AS selected_area_share
FROM preview_ranked
GROUP BY variant_id, threshold_index;

SELECT
  'v0_3_equal_group_read_only_preview_r150' AS preview_id,
  'INTERNAL_SIMULATION_ONLY' AS use_state,
  'NO_TRUSTED_RESULT' AS evidence_state,
  'PROHIBITED' AS operational_use,
  'ORDINAL_SIMULATION_INDEX_NOT_PROBABILITY' AS score_semantics,
  STRUCT(
    CAST(1.0 / 3.0 AS FLOAT64) AS food_group_weight,
    CAST(1.0 / 3.0 AS FLOAT64) AS sewer_group_weight,
    CAST(1.0 / 3.0 AS FLOAT64) AS renewal_group_weight,
    150 AS renewal_cell_footprint_window_m,
    0.10 AS selected_total_city_area_target_share,
    'NULL_NOT_DYNAMIC_REWEIGHT' AS missing_group_action
  ) AS fixed_assumptions,
  STRUCT(
    COUNT(*) AS total_cells,
    COUNTIF(food_score IS NOT NULL) AS food_scoreable_cells,
    COUNTIF(sewer_system_type_score IS NOT NULL)
      AS v0_1_sewer_scoreable_cells,
    COUNTIF(sewer_attribute_index IS NOT NULL)
      AS v0_2_sewer_scoreable_cells,
    COUNTIF(approved_rebuilding_admin_site_r150 IS NOT NULL)
      AS renewal_scoreable_cells,
    COUNTIF(v0_3_equal_group_index_r150 IS NOT NULL)
      AS composite_scoreable_cells,
    COUNTIF(renewal_admin_site_count_r150 > 0)
      AS renewal_nonzero_cells
  ) AS component_qa,
  ARRAY(
    SELECT AS STRUCT *
    FROM preview_variant_summary
    ORDER BY variant_id
  ) AS variant_summary,
  ARRAY(
    SELECT AS STRUCT *
    FROM preview_pairwise
    ORDER BY left_variant, right_variant
  ) AS pairwise_comparison,
  ARRAY(
    SELECT AS STRUCT
      component.cell_id,
      component.cell_token,
      component.centroid_longitude,
      component.centroid_latitude,
      component.food_score,
      component.sewer_attribute_index,
      component.renewal_admin_site_count_r150,
      component.approved_rebuilding_admin_site_r150,
      component.v0_3_equal_group_index_r150,
      ranked.rank_within_scoreable_support,
      ranked.selected_scenario_area_flag,
      SAFE_DIVIDE(
        component.v0_3_equal_group_index_r150,
        MAX(component.v0_3_equal_group_index_r150) OVER ()
      ) AS relative_preview_display_value
    FROM preview_components AS component
    JOIN preview_ranked AS ranked
      ON ranked.cell_id = component.cell_id
      AND ranked.variant_id =
        'v0_3_equal_group_internal_simulation_r150'
    WHERE component.v0_3_equal_group_index_r150 IS NOT NULL
    ORDER BY
      component.v0_3_equal_group_index_r150 DESC,
      component.cell_id
    LIMIT 50
  ) AS top_composite_cells
FROM preview_components;
