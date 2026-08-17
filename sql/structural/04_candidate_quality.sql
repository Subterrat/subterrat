SELECT
  COUNT(*) AS total_cells,
  COUNTIF(food_market_sites_per_km2 > 0) AS food_nonzero_cells,
  SUM(CAST(ROUND(
    food_market_sites_per_km2 * eligible_area_m2 / 1000000
  ) AS INT64)) AS food_market_site_count_reconstructed,
  COUNTIF(sewer_access_record_count_for_qa IS NOT NULL) AS sewer_recorded_cells,
  SUM(sewer_access_record_count_for_qa) AS sewer_access_record_count,
  COUNTIF(sanitary_system_record_share IS NOT NULL) AS sewer_system_type_cells,
  COUNTIF(valid_elevation_m_candidate IS NOT NULL) AS sewer_elevation_candidate_cells,
  COUNTIF(abandoned_building_count IS NOT NULL) AS abandoned_located_cells,
  COUNTIF(
    sanitary_system_record_share IS NOT NULL
    AND abandoned_building_count IS NOT NULL
  ) AS full_three_group_candidate_cells,
  COUNT(DISTINCT feature_snapshot_id) AS feature_snapshot_version_count,
  ANY_VALUE(feature_snapshot_id) AS feature_snapshot_id
FROM
  `devjam26aug17tpe-1270.subterrat_features.cell_features_t0_candidate`;
