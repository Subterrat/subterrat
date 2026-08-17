-- READ-ONLY MAP PAYLOAD PREVIEW ONLY.
--
-- Produces one row per analysis cell for BigQuery geographic inspection or a
-- later internal React heat-surface adapter. All derived objects are
-- temporary. Missing sewer-support cells stay present with NULL composite
-- values rather than being encoded as zero. The query does not read Rat Radar
-- and does not create a serving table.

CREATE TEMP TABLE map_preview_components AS
WITH
cells AS (
  SELECT
    grid_version,
    cell_id,
    cell_token,
    eligible_geom,
    eligible_area_m2,
    centroid_longitude,
    centroid_latitude
  FROM `devjam26aug17tpe-1270.subterrat_curated.analysis_cells`
  WHERE grid_version = 'taipei_county_1140318_s2_l15_v1'
),
food AS (
  SELECT
    cell_id,
    food_score,
    sewer_score AS sewer_system_type_score
  FROM `devjam26aug17tpe-1270.subterrat_predictions.map_hotspot_cells_t0`
  WHERE
    freeze_id = 't0-layerwise-development-20260817-v2'
    AND score_semantics = 'LAYER_SCORE_NOT_PROBABILITY'
),
sewer_pivot AS (
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
sewer AS (
  SELECT
    cell_id,
    sewer_system_type AS sewer_system_type_diagnostic,
    surface_elevation AS surface_elevation_diagnostic,
    connected_pipe_diameter AS connected_pipe_diameter_diagnostic,
    connected_pipe_depth AS connected_pipe_depth_diagnostic,
    connected_pipe_age AS connected_pipe_age_diagnostic,
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
  FROM sewer_pivot
),
renewal AS (
  SELECT
    cell_id,
    MAX(IF(analysis_window_m = 0, admin_site_count, NULL))
      AS renewal_admin_site_count_r0,
    MAX(IF(analysis_window_m = 150, admin_site_count, NULL))
      AS renewal_admin_site_count_r150,
    MAX(IF(analysis_window_m = 300, admin_site_count, NULL))
      AS renewal_admin_site_count_r300,
    MAX(IF(
      analysis_window_m = 0,
      admin_site_empirical_percentile,
      NULL
    )) AS approved_rebuilding_admin_site_r0,
    MAX(IF(
      analysis_window_m = 150,
      admin_site_empirical_percentile,
      NULL
    )) AS approved_rebuilding_admin_site_r150,
    MAX(IF(
      analysis_window_m = 300,
      admin_site_empirical_percentile,
      NULL
    )) AS approved_rebuilding_admin_site_r300
  FROM
    `devjam26aug17tpe-1270.subterrat_features.urban_renewal_admin_site_metrics_v0_3_internal_simulation`
  WHERE
    source_snapshot_id =
      'f31369ef4f27e6028db450051550e52f45b43f3f4e8f723ae9c50ac4ff0b1f6e'
    AND analysis_window_m IN (0, 150, 300)
    AND use_state = 'INTERNAL_SIMULATION_ONLY'
    AND evidence_state = 'NO_TRUSTED_RESULT'
  GROUP BY cell_id
)
SELECT
  cells.*,
  food.food_score,
  food.sewer_system_type_score,
  sewer.sewer_system_type_diagnostic,
  sewer.surface_elevation_diagnostic,
  sewer.connected_pipe_diameter_diagnostic,
  sewer.connected_pipe_depth_diagnostic,
  sewer.connected_pipe_age_diagnostic,
  sewer.sewer_attribute_index,
  renewal.renewal_admin_site_count_r0,
  renewal.renewal_admin_site_count_r150,
  renewal.renewal_admin_site_count_r300,
  renewal.approved_rebuilding_admin_site_r0,
  renewal.approved_rebuilding_admin_site_r150,
  renewal.approved_rebuilding_admin_site_r300,
  IF(
    food.food_score IS NOT NULL
      AND sewer.sewer_attribute_index IS NOT NULL
      AND renewal.approved_rebuilding_admin_site_r150 IS NOT NULL,
    (
      food.food_score
      + sewer.sewer_attribute_index
      + renewal.approved_rebuilding_admin_site_r150
    ) / 3,
    NULL
  ) AS v0_3_equal_group_index_r150
FROM cells
LEFT JOIN food USING (cell_id)
LEFT JOIN sewer USING (cell_id)
LEFT JOIN renewal USING (cell_id);

ASSERT (
  SELECT
    COUNT(*) = 3420
    AND COUNT(*) = COUNT(DISTINCT cell_id)
    AND COUNTIF(v0_3_equal_group_index_r150 IS NOT NULL) = 1589
    AND COUNTIF(
      v0_3_equal_group_index_r150 IS NOT NULL
      AND (
        eligible_geom IS NULL
        OR centroid_longitude IS NULL
        OR centroid_latitude IS NULL
      )
    ) = 0
    AND COUNTIF(v0_3_equal_group_index_r150 NOT BETWEEN 0 AND 1) = 0
  FROM map_preview_components
) AS 'v0.3 map preview component support or geometry is invalid';

CREATE TEMP TABLE map_preview_ranked AS
WITH
area_ranked AS (
  SELECT
    *,
    SUM(IF(
      v0_3_equal_group_index_r150 IS NULL,
      0,
      eligible_area_m2
    )) OVER (
      ORDER BY v0_3_equal_group_index_r150 DESC NULLS LAST, cell_id
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_scored_area_m2,
    SUM(eligible_area_m2) OVER () AS total_city_area_m2,
    SUM(IF(
      v0_3_equal_group_index_r150 IS NOT NULL,
      eligible_area_m2,
      0
    )) OVER () AS scoreable_area_m2,
    MAX(v0_3_equal_group_index_r150) OVER () AS display_scale_max
  FROM map_preview_components
),
threshold AS (
  SELECT MIN(v0_3_equal_group_index_r150) AS threshold_index
  FROM area_ranked
  WHERE
    v0_3_equal_group_index_r150 IS NOT NULL
    AND cumulative_scored_area_m2 - eligible_area_m2
      < total_city_area_m2 * 0.10
),
score_ranks AS (
  SELECT
    cell_id,
    PERCENT_RANK() OVER (
      ORDER BY v0_3_equal_group_index_r150
    ) AS rank_within_scoreable_support
  FROM area_ranked
  WHERE v0_3_equal_group_index_r150 IS NOT NULL
)
SELECT
  area_ranked.*,
  score_ranks.rank_within_scoreable_support,
  area_ranked.v0_3_equal_group_index_r150 >= threshold.threshold_index
    AS selected_scenario_area_flag,
  threshold.threshold_index
FROM area_ranked
JOIN score_ranks USING (cell_id)
CROSS JOIN threshold
WHERE area_ranked.v0_3_equal_group_index_r150 IS NOT NULL;

ASSERT (
  SELECT
    COUNT(*) = 1589
    AND COUNT(*) = COUNT(DISTINCT cell_id)
    AND COUNTIF(rank_within_scoreable_support NOT BETWEEN 0 AND 1) = 0
    AND COUNTIF(display_scale_max <= 0) = 0
    AND SAFE_DIVIDE(
      SUM(IF(selected_scenario_area_flag, eligible_area_m2, 0)),
      ANY_VALUE(total_city_area_m2)
    ) BETWEEN 0.10 AND 0.101
  FROM map_preview_ranked
) AS 'v0.3 map preview rank, scale, or selected-area output is invalid';

CREATE TEMP TABLE map_preview_metadata AS
SELECT
  ANY_VALUE(total_city_area_m2) AS total_city_area_m2,
  ANY_VALUE(scoreable_area_m2) AS scoreable_area_m2,
  ANY_VALUE(display_scale_max) AS display_scale_max,
  ANY_VALUE(threshold_index) AS threshold_index
FROM map_preview_ranked;

SELECT
  component.cell_id,
  component.cell_token,
  ST_GEOGPOINT(
    component.centroid_longitude,
    component.centroid_latitude
  ) AS map_point,
  ST_ASGEOJSON(component.eligible_geom) AS eligible_geojson,
  component.centroid_longitude,
  component.centroid_latitude,
  component.food_score,
  component.sewer_system_type_score,
  component.sewer_system_type_diagnostic,
  component.surface_elevation_diagnostic,
  component.connected_pipe_diameter_diagnostic,
  component.connected_pipe_depth_diagnostic,
  component.connected_pipe_age_diagnostic,
  component.sewer_attribute_index,
  component.renewal_admin_site_count_r0,
  component.renewal_admin_site_count_r150,
  component.renewal_admin_site_count_r300,
  component.approved_rebuilding_admin_site_r0,
  component.approved_rebuilding_admin_site_r150,
  component.approved_rebuilding_admin_site_r300,
  component.v0_3_equal_group_index_r150,
  SAFE_DIVIDE(
    component.v0_3_equal_group_index_r150,
    metadata.display_scale_max
  ) AS relative_preview_display_value,
  ranked.rank_within_scoreable_support,
  COALESCE(ranked.selected_scenario_area_flag, FALSE)
    AS selected_scenario_area_flag,
  metadata.threshold_index,
  SAFE_DIVIDE(metadata.scoreable_area_m2, metadata.total_city_area_m2)
    AS scoreable_city_area_share,
  IF(
    component.v0_3_equal_group_index_r150 IS NULL,
    'MISSING_SEWER_COMPLETE_CASE',
    'SCORED_COMPLETE_CASE'
  ) AS support_state,
  'INTERNAL_SIMULATION_ONLY' AS use_state,
  'NO_TRUSTED_RESULT' AS evidence_state,
  'PROHIBITED' AS operational_use,
  'ORDINAL_SIMULATION_INDEX_NOT_PROBABILITY' AS score_semantics
FROM map_preview_components AS component
LEFT JOIN map_preview_ranked AS ranked USING (cell_id)
CROSS JOIN map_preview_metadata AS metadata
ORDER BY
  component.v0_3_equal_group_index_r150 DESC NULLS LAST,
  component.cell_id;
