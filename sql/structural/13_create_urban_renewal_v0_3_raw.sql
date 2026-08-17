-- Creates an immutable raw table plus a replaceable load stage for the
-- outcome-free urban-renewal CSV export. It does not read Rat Radar data.

CREATE SCHEMA IF NOT EXISTS
  `devjam26aug17tpe-1270.subterrat_raw`
OPTIONS(location = 'asia-east1');

CREATE TABLE IF NOT EXISTS
  `devjam26aug17tpe-1270.subterrat_raw.urban_renewal_point_v0_3_raw`
(
  source_snapshot_id STRING NOT NULL,
  source_snapshot_date DATE NOT NULL,
  source_uri STRING NOT NULL,
  source_file_name STRING NOT NULL,
  source_file_sha256 STRING NOT NULL,
  source_row_number INT64 NOT NULL,
  source_row_sha256 STRING NOT NULL,
  renewal_record_id STRING NOT NULL,
  layer_name STRING NOT NULL,
  record_number STRING,
  district STRING,
  current_status STRING,
  approval_date_raw STRING,
  business_plan_approval_date_raw STRING,
  announcement_date_raw STRING,
  completion_year_raw STRING,
  longitude FLOAT64,
  latitude FLOAT64,
  phase_group STRING NOT NULL,
  primary_scenario_included BOOL NOT NULL,
  quality_flags ARRAY<STRING>
)
PARTITION BY source_snapshot_date
CLUSTER BY source_snapshot_id, renewal_record_id
OPTIONS(
  description = 'Immutable outcome-free urban-renewal point exports for the v0.3 scenario candidate'
);

CREATE OR REPLACE TABLE
  `devjam26aug17tpe-1270.subterrat_raw.urban_renewal_point_v0_3_load_stage`
OPTIONS(
  description = 'Replaceable load stage; canonical rows are inserted only by immutable MERGE'
) AS
SELECT
  source_snapshot_id,
  source_snapshot_date,
  source_uri,
  source_file_name,
  source_file_sha256,
  source_row_number,
  source_row_sha256,
  renewal_record_id,
  layer_name,
  record_number,
  district,
  current_status,
  approval_date_raw,
  business_plan_approval_date_raw,
  announcement_date_raw,
  completion_year_raw,
  longitude,
  latitude,
  phase_group,
  primary_scenario_included,
  quality_flags
FROM `devjam26aug17tpe-1270.subterrat_raw.urban_renewal_point_v0_3_raw`
WHERE FALSE;
