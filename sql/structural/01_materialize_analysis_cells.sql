-- Expected input:
-- `devjam26aug17tpe-1270.subterrat_raw.taipei_s2_l15_grid_raw`
-- loaded from scripts/build_taipei_s2_grid.py output.

CREATE OR REPLACE TABLE
  `devjam26aug17tpe-1270.subterrat_curated.analysis_cells`
CLUSTER BY cell_id AS
SELECT
  grid_version,
  boundary_version,
  boundary_dataset_uri,
  boundary_resource_uri,
  boundary_sha256,
  s2_level,
  cell_id,
  cell_token,
  centroid_longitude,
  centroid_latitude,
  SAFE.ST_GEOGFROMGEOJSON(full_geojson) AS full_geom,
  SAFE.ST_GEOGFROMGEOJSON(clipped_geojson) AS eligible_geom,
  eligible_area_m2
FROM
  `devjam26aug17tpe-1270.subterrat_raw.taipei_s2_l15_grid_raw`;

ASSERT (
  SELECT COUNT(*) = COUNT(DISTINCT cell_id)
  FROM `devjam26aug17tpe-1270.subterrat_curated.analysis_cells`
) AS 'analysis_cells.cell_id must be unique';

ASSERT (
  SELECT COUNTIF(
    s2_level != 15
    OR full_geom IS NULL
    OR eligible_geom IS NULL
    OR eligible_area_m2 <= 0
  ) = 0
  FROM `devjam26aug17tpe-1270.subterrat_curated.analysis_cells`
) AS 'analysis_cells contains invalid level, geometry, or area';
