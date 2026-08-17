-- Creates the immutable canonical raw table. Load each local NDJSON export
-- into `sanitary_pipe_segment_v0_2_load_stage`, then run step 09 to merge it.
-- This script never reads outcome data and does not modify the v0.1 freeze.

CREATE SCHEMA IF NOT EXISTS
  `devjam26aug17tpe-1270.subterrat_raw`
OPTIONS(location = 'asia-east1');

CREATE TABLE IF NOT EXISTS
  `devjam26aug17tpe-1270.subterrat_raw.sanitary_pipe_segment_v0_2_raw`
(
  source_snapshot_id STRING NOT NULL,
  source_snapshot_date DATE NOT NULL,
  source_dataset_id STRING NOT NULL,
  source_resource_id STRING NOT NULL,
  source_file_name STRING NOT NULL,
  source_file_sha256 STRING NOT NULL,
  source_row_sha256 STRING NOT NULL,
  segment_id STRING NOT NULL,
  start_node_id STRING,
  end_node_id STRING,
  source_crs STRING,
  source_dimension INT64,
  geometry_wkt_wgs84 STRING,
  geometry_2d_length_m FLOAT64,
  reported_length_m FLOAT64,
  diameter_unit_code STRING,
  pipe_width_raw FLOAT64,
  pipe_height_raw FLOAT64,
  circular_diameter_m FLOAT64,
  start_cover_depth_m FLOAT64,
  end_cover_depth_m FLOAT64,
  mean_cover_depth_m FLOAT64,
  install_date DATE,
  pipe_material STRING,
  operation_type_code STRING,
  pipe_type_code STRING,
  use_status_code STRING,
  data_status_code STRING,
  is_active BOOL NOT NULL,
  is_surveyed BOOL NOT NULL,
  quality_flags ARRAY<STRING>
)
PARTITION BY source_snapshot_date
CLUSTER BY source_snapshot_id, segment_id
OPTIONS(
  description = 'Immutable outcome-free Taipei sanitary-pipe XML exports for sewer v0.2 candidates'
);

CREATE OR REPLACE TABLE
  `devjam26aug17tpe-1270.subterrat_raw.sanitary_pipe_segment_v0_2_load_stage`
OPTIONS(
  description = 'Replaceable load stage; canonical raw rows are inserted only by immutable MERGE'
) AS
SELECT *
FROM `devjam26aug17tpe-1270.subterrat_raw.sanitary_pipe_segment_v0_2_raw`
WHERE FALSE;
