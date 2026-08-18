-- Required named query parameter:
--   source_snapshot_id STRING: emitted by export_taipei_urban_renewal_bq.py
--
-- Load contracts/bigquery_urban_renewal_v0_3_schema.json into the stage first.

ASSERT (
  SELECT COUNT(*) > 0
  FROM `devjam26aug17tpe-1270.subterrat_raw.urban_renewal_point_v0_3_load_stage`
) AS 'urban-renewal v0.3 load stage must not be empty';

ASSERT (
  SELECT
    COUNT(*) = 2365
    AND COUNT(DISTINCT source_snapshot_id) = 1
    AND ANY_VALUE(source_snapshot_id) = @source_snapshot_id
    AND COUNT(DISTINCT source_file_sha256) = 1
    AND ANY_VALUE(source_file_sha256) =
      'b1743a3d63105c5d1ea25251e1d881825c40ef7a905d902ebd0d455685c9cde2'
    AND COUNT(*) = COUNT(DISTINCT renewal_record_id)
    AND COUNTIF(
      source_snapshot_id IS NULL
      OR source_row_sha256 IS NULL
      OR renewal_record_id IS NULL
      OR layer_name IS NULL
      OR phase_group IS NULL
    ) = 0
  FROM `devjam26aug17tpe-1270.subterrat_raw.urban_renewal_point_v0_3_load_stage`
) AS 'staged urban-renewal snapshot identity, count, or uniqueness is invalid';

ASSERT (
  SELECT COUNT(*) = 0
  FROM
    `devjam26aug17tpe-1270.subterrat_raw.urban_renewal_point_v0_3_raw` AS target
  JOIN
    `devjam26aug17tpe-1270.subterrat_raw.urban_renewal_point_v0_3_load_stage` AS source
  USING (source_snapshot_id, renewal_record_id)
  WHERE target.source_row_sha256 != source.source_row_sha256
) AS 'immutable urban-renewal snapshot conflicts with an existing row';

MERGE
  `devjam26aug17tpe-1270.subterrat_raw.urban_renewal_point_v0_3_raw` AS target
USING
  `devjam26aug17tpe-1270.subterrat_raw.urban_renewal_point_v0_3_load_stage` AS source
ON
  target.source_snapshot_id = source.source_snapshot_id
  AND target.renewal_record_id = source.renewal_record_id
WHEN NOT MATCHED THEN
  INSERT (
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
  )
  VALUES (
    source.source_snapshot_id,
    source.source_snapshot_date,
    source.source_uri,
    source.source_file_name,
    source.source_file_sha256,
    source.source_row_number,
    source.source_row_sha256,
    source.renewal_record_id,
    source.layer_name,
    source.record_number,
    source.district,
    source.current_status,
    source.approval_date_raw,
    source.business_plan_approval_date_raw,
    source.announcement_date_raw,
    source.completion_year_raw,
    source.longitude,
    source.latitude,
    source.phase_group,
    source.primary_scenario_included,
    source.quality_flags
  );

CREATE OR REPLACE TABLE
  `devjam26aug17tpe-1270.subterrat_curated.urban_renewal_point_v0_3_candidate`
CLUSTER BY phase_group, renewal_record_id AS
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
  IF(
    longitude BETWEEN 121.3 AND 121.8
      AND latitude BETWEEN 24.8 AND 25.3,
    ST_GEOGPOINT(longitude, latitude),
    NULL
  ) AS geom_wgs84,
  phase_group,
  primary_scenario_included,
  quality_flags,
  'BLOCKED_SOURCE_REUSE_LICENSE_COMPLETENESS_AND_TAXONOMY_INCOMPLETE'
    AS source_lineage_state,
  'REPOSITORY_OBSERVED_DATE_NOT_PROVIDER_PUBLICATION_DATE'
    AS snapshot_date_semantics,
  'OUTCOME_BLINDED_COMPONENT_SOURCE' AS evidence_state
FROM `devjam26aug17tpe-1270.subterrat_raw.urban_renewal_point_v0_3_raw`
WHERE source_snapshot_id = @source_snapshot_id;

ASSERT (
  SELECT
    COUNT(*) = 2365
    AND COUNT(*) = COUNT(DISTINCT renewal_record_id)
    AND COUNTIF(geom_wgs84 IS NULL) = 0
    AND COUNTIF(primary_scenario_included) = 250
    AND COUNTIF(phase_group = 'COMPLETED') = 347
    AND COUNTIF(phase_group = 'APPROVED_PROJECT_UNKNOWN_STATUS') = 79
    AND COUNTIF(phase_group = 'PLANNING_OR_DESIGNATION') = 1604
    AND COUNTIF(phase_group = 'GOVERNMENT_LED_UNKNOWN_PHASE') = 85
    AND COUNTIF(evidence_state != 'OUTCOME_BLINDED_COMPONENT_SOURCE') = 0
  FROM `devjam26aug17tpe-1270.subterrat_curated.urban_renewal_point_v0_3_candidate`
) AS 'curated urban-renewal v0.3 identity, coordinates, or phase counts are invalid';
