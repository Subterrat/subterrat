-- Google Maps-ready, aggregate-cell payload. Exact source addresses and raw
-- Rat Radar points are intentionally absent.

CREATE OR REPLACE TABLE
  `devjam26aug17tpe-1270.subterrat_predictions.map_hotspot_cells_t0`
CLUSTER BY cell_id AS
WITH
scores AS (
  SELECT
    cell_id,
    MAX(IF(variant_id = 'food_market_only', layer_score, NULL)) AS food_score,
    LOGICAL_OR(IF(variant_id = 'food_market_only', top_10pct_area_flag, FALSE))
      AS food_top_area,
    MAX(IF(variant_id = 'sewer_system_type_only', layer_score, NULL)) AS sewer_score,
    LOGICAL_OR(IF(variant_id = 'sewer_system_type_only', top_10pct_area_flag, FALSE))
      AS sewer_top_area,
    MAX(IF(
      variant_id = 'sewer_system_type_only',
      candidate_state,
      NULL
    )) AS sewer_coverage_state
  FROM `devjam26aug17tpe-1270.subterrat_predictions.layer_scores_t0`
  GROUP BY cell_id
),
building_overlay AS (
  SELECT
    S2_CELLIDFROMPOINT(geom_wgs84, level => 15) AS cell_id,
    COUNT(DISTINCT CONCAT(district_code, ':', address_key))
      AS unused_public_building_address_point_count
  FROM
    `devjam26aug17tpe-1270.subterrat_curated.unused_public_building_address_point_candidate_geo`
  GROUP BY cell_id
)
SELECT
  cells.grid_version,
  cells.cell_id,
  cells.cell_token,
  cells.centroid_longitude,
  cells.centroid_latitude,
  ST_ASGEOJSON(cells.eligible_geom) AS eligible_geojson,
  cells.eligible_area_m2,
  scores.food_score,
  scores.food_top_area,
  scores.sewer_score,
  scores.sewer_top_area,
  scores.sewer_score IS NOT NULL AS sewer_has_score,
  scores.sewer_coverage_state,
  COALESCE(building_overlay.unused_public_building_address_point_count, 0)
    AS unused_public_building_address_point_count,
  'PROVISIONAL_OVERLAY_NOT_CITYWIDE_FEATURE' AS building_overlay_state,
  't0-layerwise-development-20260817-v2' AS freeze_id,
  'DETERMINISTIC_HOTSPOT_RANKING' AS model_kind,
  'LAYER_SCORE_NOT_PROBABILITY' AS score_semantics,
  'NO_TRUSTED_RESULT' AS evidence_state
FROM `devjam26aug17tpe-1270.subterrat_curated.analysis_cells` AS cells
LEFT JOIN scores USING (cell_id)
LEFT JOIN building_overlay USING (cell_id);

ASSERT (
  SELECT
    COUNT(*) = 3420
    AND COUNT(*) = COUNT(DISTINCT cell_id)
    AND COUNTIF(eligible_geojson IS NULL) = 0
    AND SUM(unused_public_building_address_point_count) = 18
    AND COUNTIF(score_semantics != 'LAYER_SCORE_NOT_PROBABILITY') = 0
  FROM `devjam26aug17tpe-1270.subterrat_predictions.map_hotspot_cells_t0`
) AS 'map payload row, geometry, overlay, or semantics mismatch';
