-- Rat Radar and every other outcome table are intentionally absent.
-- This query creates feature candidates, not a fitted model.

CREATE SCHEMA IF NOT EXISTS
  `devjam26aug17tpe-1270.subterrat_features`
OPTIONS(location = 'asia-east1');

CREATE OR REPLACE TABLE
  `devjam26aug17tpe-1270.subterrat_features.cell_features_t0_candidate`
CLUSTER BY cell_id AS
WITH
food AS (
  SELECT
    S2_CELLIDFROMPOINT(geom_wgs84, level => 15) AS cell_id,
    COUNT(*) AS food_market_site_count
  FROM `devjam26aug17tpe-1270.subterrat_curated.food_site_candidate_geo`
  WHERE geom_wgs84 IS NOT NULL
  GROUP BY cell_id
),
sewer AS (
  SELECT
    S2_CELLIDFROMPOINT(geom_wgs84, level => 15) AS cell_id,
    COUNT(*) AS sewer_access_record_count_for_qa,
    SAFE_DIVIDE(
      COUNTIF(LOWER(source_system_type) = 'sanitary'),
      COUNT(*)
    ) AS sanitary_system_record_share,
    AVG(IF(
      surface_elevation_m IS NOT NULL AND surface_elevation_m != 0,
      surface_elevation_m,
      NULL
    )) AS valid_elevation_m_candidate
  FROM `devjam26aug17tpe-1270.subterrat_curated.sewer_access_point_candidate_geo`
  WHERE
    geom_wgs84 IS NOT NULL
    AND NOT duplicate_id_conflict
  GROUP BY cell_id
),
abandoned AS (
  SELECT
    S2_CELLIDFROMPOINT(ST_GEOGPOINT(longitude, latitude), level => 15) AS cell_id,
    COUNT(*) AS abandoned_building_count
  FROM `devjam26aug17tpe-1270.subterrat_curated.unused_public_building_candidate`
  WHERE longitude IS NOT NULL AND latitude IS NOT NULL
  GROUP BY cell_id
),
source_versions AS (
  SELECT
    (
      SELECT STRING_AGG(DISTINCT snapshot_id, ',' ORDER BY snapshot_id)
      FROM `devjam26aug17tpe-1270.subterrat_curated.food_site_candidate_geo`
    ) AS food_snapshot_ids,
    (
      SELECT STRING_AGG(DISTINCT snapshot_id, ',' ORDER BY snapshot_id)
      FROM `devjam26aug17tpe-1270.subterrat_curated.sewer_access_point_candidate_geo`
    ) AS sewer_snapshot_ids,
    (
      SELECT STRING_AGG(DISTINCT snapshot_id, ',' ORDER BY snapshot_id)
      FROM `devjam26aug17tpe-1270.subterrat_curated.unused_public_building_candidate`
    ) AS abandoned_snapshot_ids
)
SELECT
  cells.grid_version,
  TO_HEX(SHA256(CONCAT(
    cells.grid_version,
    '|food=', COALESCE(source_versions.food_snapshot_ids, ''),
    '|sewer=', COALESCE(source_versions.sewer_snapshot_ids, ''),
    '|abandoned=', COALESCE(source_versions.abandoned_snapshot_ids, '')
  ))) AS feature_snapshot_id,
  cells.cell_id,
  cells.cell_token,
  cells.eligible_area_m2,
  SAFE_DIVIDE(COALESCE(food.food_market_site_count, 0), cells.eligible_area_m2)
    * 1000000 AS food_market_sites_per_km2,
  sewer.sewer_access_record_count_for_qa,
  sewer.sanitary_system_record_share,
  sewer.valid_elevation_m_candidate,
  abandoned.abandoned_building_count
FROM `devjam26aug17tpe-1270.subterrat_curated.analysis_cells` AS cells
CROSS JOIN source_versions
LEFT JOIN food USING (cell_id)
LEFT JOIN sewer USING (cell_id)
LEFT JOIN abandoned USING (cell_id);

ASSERT (
  SELECT COUNT(*) = COUNT(DISTINCT cell_id)
  FROM `devjam26aug17tpe-1270.subterrat_features.cell_features_t0_candidate`
) AS 'cell_features_t0_candidate.cell_id must be unique';
