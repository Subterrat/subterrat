-- Builds the approved-rebuilding administrative-site proxy used by v0.3.
-- Source field `編號` is treated only as an undocumented administrative site
-- key. It is not claimed to be an authoritative project identifier.

CREATE OR REPLACE TABLE
  `devjam26aug17tpe-1270.subterrat_curated.urban_renewal_admin_site_v0_3_internal_simulation`
CLUSTER BY admin_site_key AS
WITH
included_rows AS (
  SELECT
    source_snapshot_id,
    source_row_number,
    TRIM(NORMALIZE(record_number, NFKC)) AS normalized_record_number,
    geom_wgs84
  FROM
    `devjam26aug17tpe-1270.subterrat_curated.urban_renewal_point_v0_3_candidate`
  WHERE
    primary_scenario_included
    AND geom_wgs84 IS NOT NULL
    AND NULLIF(TRIM(NORMALIZE(record_number, NFKC)), '') IS NOT NULL
),
sites AS (
  SELECT
    source_snapshot_id,
    normalized_record_number,
    TO_HEX(SHA256(CONCAT(
      source_snapshot_id,
      '|',
      normalized_record_number
    ))) AS admin_site_key,
    ARRAY_AGG(
      geom_wgs84
      ORDER BY source_row_number
      LIMIT 1
    )[OFFSET(0)] AS representative_geom_wgs84,
    MIN(source_row_number) AS representative_source_row_number,
    COUNT(*) AS source_record_count,
    COUNT(DISTINCT ST_ASTEXT(geom_wgs84)) AS unique_coordinate_count
  FROM included_rows
  GROUP BY source_snapshot_id, normalized_record_number
)
SELECT
  *,
  'SOURCE_RECORD_NUMBER_PROVIDER_SEMANTICS_UNDOCUMENTED' AS site_key_semantics,
  'LOWEST_SOURCE_ROW_NUMBER' AS representative_geometry_rule,
  'APPROVED_REBUILDING_ADMIN_PROXY_NOT_PHYSICAL_WORKS' AS construct_semantics,
  'INTERNAL_SIMULATION_ONLY' AS use_state,
  'NO_TRUSTED_RESULT' AS evidence_state
FROM sites;

ASSERT (
  SELECT
    COUNT(*) = 248
    AND COUNT(*) = COUNT(DISTINCT admin_site_key)
    AND COUNT(DISTINCT source_snapshot_id) = 1
    AND SUM(source_record_count) = 250
    AND COUNTIF(source_record_count > 1) = 2
    AND COUNTIF(representative_geom_wgs84 IS NULL) = 0
    AND COUNTIF(use_state != 'INTERNAL_SIMULATION_ONLY') = 0
    AND COUNTIF(evidence_state != 'NO_TRUSTED_RESULT') = 0
  FROM
    `devjam26aug17tpe-1270.subterrat_curated.urban_renewal_admin_site_v0_3_internal_simulation`
) AS 'urban-renewal v0.3 administrative-site identity or deduplication is invalid';

-- The 150 m value is a preregistered local analysis window around the cell
-- footprint. It is not a diffusion, displacement, home-range, or biological
-- movement parameter. The 0 m and 300 m values are sensitivity windows.
CREATE OR REPLACE TABLE
  `devjam26aug17tpe-1270.subterrat_features.urban_renewal_admin_site_metrics_v0_3_internal_simulation`
CLUSTER BY analysis_window_m, cell_id AS
WITH
cells AS (
  SELECT
    grid_version,
    cell_id,
    cell_token,
    eligible_geom,
    eligible_area_m2
  FROM `devjam26aug17tpe-1270.subterrat_curated.analysis_cells`
),
admin_sites AS (
  SELECT
    admin_site_key,
    source_snapshot_id,
    representative_geom_wgs84
  FROM
    `devjam26aug17tpe-1270.subterrat_curated.urban_renewal_admin_site_v0_3_internal_simulation`
),
site_snapshot AS (
  SELECT DISTINCT source_snapshot_id
  FROM admin_sites
),
analysis_windows AS (
  SELECT analysis_window_m
  FROM UNNEST([0, 150, 300]) AS analysis_window_m
),
counts AS (
  SELECT
    cells.grid_version,
    cells.cell_id,
    cells.cell_token,
    cells.eligible_area_m2,
    analysis_windows.analysis_window_m,
    site_snapshot.source_snapshot_id,
    COUNT(DISTINCT admin_sites.admin_site_key) AS admin_site_count
  FROM cells
  CROSS JOIN analysis_windows
  CROSS JOIN site_snapshot
  LEFT JOIN admin_sites
    ON ST_DWITHIN(
      admin_sites.representative_geom_wgs84,
      cells.eligible_geom,
      CAST(analysis_windows.analysis_window_m AS FLOAT64)
    )
  GROUP BY
    cells.grid_version,
    cells.cell_id,
    cells.cell_token,
    cells.eligible_area_m2,
    analysis_windows.analysis_window_m,
    site_snapshot.source_snapshot_id
),
ranked AS (
  SELECT
    *,
    IF(
      admin_site_count = 0,
      0.0,
      PERCENT_RANK() OVER (
        PARTITION BY analysis_window_m
        ORDER BY admin_site_count
      )
    ) AS admin_site_empirical_percentile
  FROM counts
)
SELECT
  grid_version,
  source_snapshot_id,
  cell_id,
  cell_token,
  eligible_area_m2,
  analysis_window_m,
  admin_site_count,
  admin_site_empirical_percentile,
  IF(analysis_window_m = 150, 'PREREGISTERED_PRIMARY', 'SENSITIVITY')
    AS analysis_window_role,
  'CELL_FOOTPRINT_BUFFER' AS spatial_support_semantics,
  'BIGQUERY_GEOGRAPHY_ST_DWITHIN_METRES' AS distance_engine,
  'ZERO_MEANS_NO_MATCH_IN_OBSERVED_FILE_SCOPE_NOT_TRUE_ABSENCE'
    AS zero_semantics,
  'APPROVED_REBUILDING_ADMIN_PROXY_NOT_PHYSICAL_WORKS'
    AS construct_semantics,
  'INTERNAL_SIMULATION_ONLY' AS use_state,
  'NO_TRUSTED_RESULT' AS evidence_state
FROM ranked;

ASSERT (
  SELECT
    COUNT(*) = 3420 * 3
    AND COUNT(*) = COUNT(DISTINCT CONCAT(
      CAST(analysis_window_m AS STRING), ':', CAST(cell_id AS STRING)
    ))
    AND COUNT(DISTINCT analysis_window_m) = 3
    AND COUNT(DISTINCT source_snapshot_id) = 1
    AND COUNTIF(admin_site_empirical_percentile NOT BETWEEN 0 AND 1) = 0
    AND COUNTIF(
      admin_site_count = 0
      AND admin_site_empirical_percentile != 0
    ) = 0
    AND COUNTIF(spatial_support_semantics != 'CELL_FOOTPRINT_BUFFER') = 0
    AND COUNTIF(use_state != 'INTERNAL_SIMULATION_ONLY') = 0
    AND COUNTIF(evidence_state != 'NO_TRUSTED_RESULT') = 0
  FROM
    `devjam26aug17tpe-1270.subterrat_features.urban_renewal_admin_site_metrics_v0_3_internal_simulation`
) AS 'urban-renewal v0.3 administrative-site metrics are invalid';
