-- Required named query parameter:
--   source_snapshot_id STRING: emitted by export_taipei_sanitary_pipe_bq.py
--
-- Expected staging table:
-- `subterrat_raw.sanitary_pipe_segment_v0_2_load_stage`
-- loaded with contracts/bigquery_sanitary_pipe_v0_2_schema.json.

ASSERT (
  SELECT COUNT(*) > 0
  FROM `devjam26aug17tpe-1270.subterrat_raw.sanitary_pipe_segment_v0_2_load_stage`
) AS 'sewer v0.2 load stage must not be empty';

ASSERT (
  SELECT
    COUNT(DISTINCT source_snapshot_id) = 1
    AND ANY_VALUE(source_snapshot_id) = @source_snapshot_id
    AND COUNT(*) = COUNT(DISTINCT segment_id)
    AND COUNTIF(
      source_snapshot_id IS NULL
      OR source_snapshot_date IS NULL
      OR segment_id IS NULL
      OR source_row_sha256 IS NULL
    ) = 0
  FROM `devjam26aug17tpe-1270.subterrat_raw.sanitary_pipe_segment_v0_2_load_stage`
) AS 'staged snapshot identity, uniqueness, or required fields are invalid';

ASSERT (
  SELECT COUNT(*) = 0
  FROM `devjam26aug17tpe-1270.subterrat_raw.sanitary_pipe_segment_v0_2_raw` AS target
  JOIN `devjam26aug17tpe-1270.subterrat_raw.sanitary_pipe_segment_v0_2_load_stage` AS source
    USING (source_snapshot_id, segment_id)
  WHERE target.source_row_sha256 != source.source_row_sha256
) AS 'immutable source snapshot conflicts with an existing segment';

MERGE `devjam26aug17tpe-1270.subterrat_raw.sanitary_pipe_segment_v0_2_raw` AS target
USING `devjam26aug17tpe-1270.subterrat_raw.sanitary_pipe_segment_v0_2_load_stage` AS source
ON
  target.source_snapshot_id = source.source_snapshot_id
  AND target.segment_id = source.segment_id
WHEN NOT MATCHED THEN
  INSERT ROW;

CREATE OR REPLACE TABLE
  `devjam26aug17tpe-1270.subterrat_curated.sanitary_pipe_segment_v0_2_candidate`
CLUSTER BY segment_id AS
SELECT
  source_snapshot_id,
  source_snapshot_date,
  source_dataset_id,
  source_resource_id,
  source_file_name,
  source_file_sha256,
  source_row_sha256,
  segment_id,
  start_node_id,
  end_node_id,
  source_crs,
  source_dimension,
  SAFE.ST_GEOGFROMTEXT(geometry_wkt_wgs84) AS geom_wgs84,
  geometry_2d_length_m,
  reported_length_m,
  circular_diameter_m,
  start_cover_depth_m,
  end_cover_depth_m,
  mean_cover_depth_m,
  install_date,
  IF(
    install_date IS NOT NULL AND install_date <= source_snapshot_date,
    SAFE_DIVIDE(DATE_DIFF(source_snapshot_date, install_date, DAY), 365.2425),
    NULL
  ) AS pipe_age_years_at_snapshot,
  pipe_material,
  operation_type_code,
  pipe_type_code,
  use_status_code,
  data_status_code,
  is_active,
  is_surveyed,
  quality_flags,
  'OFFICIAL_OPEN_REFERENCE_REQUIRES_PIPE_AUTHORITY_CONFIRMATION'
    AS authority_state,
  'OUTCOME_FREE_DATA_GATED_CANDIDATE' AS evidence_state
FROM `devjam26aug17tpe-1270.subterrat_raw.sanitary_pipe_segment_v0_2_raw`
WHERE source_snapshot_id = @source_snapshot_id;

ASSERT (
  SELECT
    COUNT(*) = COUNT(DISTINCT segment_id)
    AND COUNT(DISTINCT source_snapshot_id) = 1
    AND COUNTIF(evidence_state != 'OUTCOME_FREE_DATA_GATED_CANDIDATE') = 0
  FROM `devjam26aug17tpe-1270.subterrat_curated.sanitary_pipe_segment_v0_2_candidate`
) AS 'curated sewer v0.2 snapshot identity or uniqueness is invalid';
