-- Materializes five outcome-free, cell-level sewer metric candidates.
-- It intentionally preserves blocked metrics so QA can inspect them; no
-- composite or frozen prediction is produced here.

CREATE OR REPLACE TABLE
  `devjam26aug17tpe-1270.subterrat_features.sewer_metrics_v0_2_candidate`
CLUSTER BY cell_id AS
WITH
cells AS (
  SELECT *
  FROM `devjam26aug17tpe-1270.subterrat_curated.analysis_cells`
),
v0_1 AS (
  SELECT
    feature_snapshot_id AS parent_feature_snapshot_id,
    cell_id,
    sanitary_system_record_share
  FROM `devjam26aug17tpe-1270.subterrat_features.cell_features_t0_candidate`
),
elevation_points AS (
  SELECT
    S2_CELLIDFROMPOINT(geom_wgs84, level => 15) AS cell_id,
    LOWER(source_system_type) AS source_system_type,
    surface_elevation_m
  FROM `devjam26aug17tpe-1270.subterrat_curated.sewer_access_point_candidate_geo`
  WHERE
    geom_wgs84 IS NOT NULL
    AND NOT duplicate_id_conflict
    AND surface_elevation_m IS NOT NULL
    AND surface_elevation_m != 0
),
elevation AS (
  SELECT
    cell_id,
    PERCENTILE_CONT(surface_elevation_m, 0.5) OVER (
      PARTITION BY cell_id
    ) AS surface_elevation_m,
    COUNT(*) OVER (PARTITION BY cell_id) AS valid_elevation_record_count,
    COUNTIF(source_system_type = 'sanitary') OVER (PARTITION BY cell_id)
      AS sanitary_elevation_record_count,
    COUNTIF(source_system_type = 'stormwater') OVER (PARTITION BY cell_id)
      AS stormwater_elevation_record_count
  FROM elevation_points
  QUALIFY ROW_NUMBER() OVER (PARTITION BY cell_id ORDER BY cell_id) = 1
),
active_segments AS (
  SELECT *
  FROM `devjam26aug17tpe-1270.subterrat_curated.sanitary_pipe_segment_v0_2_candidate`
  WHERE is_active AND geom_wgs84 IS NOT NULL
),
pipe_snapshot AS (
  SELECT ANY_VALUE(pipes.source_snapshot_id) AS source_snapshot_id
  FROM
    `devjam26aug17tpe-1270.subterrat_curated.sanitary_pipe_segment_v0_2_candidate`
      AS pipes
  HAVING COUNT(DISTINCT pipes.source_snapshot_id) = 1
),
segment_cell_intersections AS (
  SELECT
    cells.cell_id,
    segments.source_snapshot_id,
    segments.segment_id,
    segments.circular_diameter_m,
    segments.mean_cover_depth_m,
    segments.pipe_age_years_at_snapshot,
    segments.is_surveyed,
    ST_LENGTH(ST_INTERSECTION(segments.geom_wgs84, cells.eligible_geom))
      AS clipped_length_m
  FROM active_segments AS segments
  JOIN cells
    ON ST_INTERSECTS(segments.geom_wgs84, cells.eligible_geom)
),
pipe_metrics AS (
  SELECT
    cell_id,
    ANY_VALUE(source_snapshot_id) AS source_snapshot_id,
    COUNT(DISTINCT segment_id) AS matched_segment_count,
    COUNT(DISTINCT IF(is_surveyed, segment_id, NULL))
      AS surveyed_segment_count,
    SUM(clipped_length_m) AS active_clipped_length_m,
    SAFE_DIVIDE(
      SUM(IF(
        circular_diameter_m IS NOT NULL,
        circular_diameter_m * clipped_length_m,
        0
      )),
      SUM(IF(circular_diameter_m IS NOT NULL, clipped_length_m, 0))
    ) AS connected_pipe_diameter_m,
    SUM(IF(circular_diameter_m IS NOT NULL, clipped_length_m, 0))
      AS valid_diameter_clipped_length_m,
    SAFE_DIVIDE(
      SUM(IF(
        mean_cover_depth_m IS NOT NULL,
        mean_cover_depth_m * clipped_length_m,
        0
      )),
      SUM(IF(mean_cover_depth_m IS NOT NULL, clipped_length_m, 0))
    ) AS connected_pipe_depth_m,
    SUM(IF(mean_cover_depth_m IS NOT NULL, clipped_length_m, 0))
      AS valid_depth_clipped_length_m,
    SAFE_DIVIDE(
      SUM(IF(
        pipe_age_years_at_snapshot IS NOT NULL,
        pipe_age_years_at_snapshot * clipped_length_m,
        0
      )),
      SUM(IF(pipe_age_years_at_snapshot IS NOT NULL, clipped_length_m, 0))
    ) AS connected_pipe_age_years,
    SUM(IF(pipe_age_years_at_snapshot IS NOT NULL, clipped_length_m, 0))
      AS valid_age_clipped_length_m
  FROM segment_cell_intersections
  WHERE clipped_length_m > 0
  GROUP BY cell_id
)
SELECT
  cells.grid_version,
  v0_1.parent_feature_snapshot_id,
  pipe_snapshot.source_snapshot_id,
  cells.cell_id,
  cells.cell_token,
  cells.eligible_area_m2,
  v0_1.sanitary_system_record_share,
  elevation.surface_elevation_m,
  elevation.valid_elevation_record_count,
  elevation.sanitary_elevation_record_count,
  elevation.stormwater_elevation_record_count,
  pipe_metrics.matched_segment_count,
  pipe_metrics.surveyed_segment_count,
  pipe_metrics.active_clipped_length_m,
  pipe_metrics.connected_pipe_diameter_m,
  pipe_metrics.valid_diameter_clipped_length_m,
  pipe_metrics.connected_pipe_depth_m,
  pipe_metrics.valid_depth_clipped_length_m,
  pipe_metrics.connected_pipe_age_years,
  pipe_metrics.valid_age_clipped_length_m,
  'MISSING_VALUES_REMAIN_NULL' AS missing_value_policy,
  'OUTCOME_FREE_DATA_GATED_CANDIDATE' AS evidence_state
FROM cells
CROSS JOIN pipe_snapshot
LEFT JOIN v0_1 USING (cell_id)
LEFT JOIN elevation USING (cell_id)
LEFT JOIN pipe_metrics USING (cell_id);

ASSERT (
  SELECT
    COUNT(*) = COUNT(DISTINCT cell_id)
    AND COUNT(*) = 3420
    AND COUNTIF(evidence_state != 'OUTCOME_FREE_DATA_GATED_CANDIDATE') = 0
    AND COUNTIF(missing_value_policy != 'MISSING_VALUES_REMAIN_NULL') = 0
  FROM `devjam26aug17tpe-1270.subterrat_features.sewer_metrics_v0_2_candidate`
) AS 'sewer v0.2 cell metrics identity or evidence boundary is invalid';
