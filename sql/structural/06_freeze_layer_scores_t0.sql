-- Development-exposed T0 freeze for retrospective validation.
-- Required named query parameters:
--   git_head STRING: the exact repository commit running this freeze
--   repository_state STRING: e.g. COMMITTED_SOURCE

ASSERT (
  @git_head IS NOT NULL
  AND LENGTH(@git_head) = 40
  AND @repository_state IS NOT NULL
) AS 'git_head and repository_state parameters are required';

CREATE OR REPLACE TABLE
  `devjam26aug17tpe-1270.subterrat_predictions.layer_scores_t0`
CLUSTER BY variant_id, cell_id AS
SELECT * REPLACE('T0_DEVELOPMENT_FROZEN' AS evidence_state)
FROM `devjam26aug17tpe-1270.subterrat_predictions.layer_scores_t0_candidate`
WHERE variant_id IN ('food_market_only', 'sewer_system_type_only');

ASSERT (
  SELECT
    COUNT(*) = 6840
    AND COUNT(*) = COUNT(DISTINCT CONCAT(variant_id, ':', CAST(cell_id AS STRING)))
    AND COUNT(DISTINCT variant_id) = 2
    AND COUNT(DISTINCT feature_snapshot_id) = 1
    AND ANY_VALUE(feature_snapshot_id) =
      'f96837659e1d7747a10c718fb51c6e083c1f0ee83755c03b6d75d250cc77d081'
    AND COUNTIF(score_semantics != 'LAYER_SCORE_NOT_PROBABILITY') = 0
  FROM `devjam26aug17tpe-1270.subterrat_predictions.layer_scores_t0`
) AS 'frozen layer score identity or semantics mismatch';

ASSERT (
  SELECT COUNT(*) = 2
  FROM (
    SELECT variant_id
    FROM `devjam26aug17tpe-1270.subterrat_predictions.layer_scores_t0`
    GROUP BY variant_id
    HAVING SAFE_DIVIDE(
      SUM(IF(top_10pct_area_flag, eligible_area_m2, 0)),
      SUM(eligible_area_m2)
    ) BETWEEN 0.099 AND 0.15
  )
) AS 'each frozen variant must select at least 10% area with all boundary ties';

CREATE OR REPLACE TABLE
  `devjam26aug17tpe-1270.subterrat_predictions.freeze_manifest` AS
SELECT
  't0-layerwise-development-20260817-v2' AS freeze_id,
  'T0_LAYERWISE_FROZEN_AWAITING_VALIDATION' AS freeze_status,
  'DEVELOPMENT_EXPOSED_RETROSPECTIVE' AS freeze_kind,
  CURRENT_TIMESTAMP() AS frozen_at,
  'devjam26aug17tpe-1270' AS project_id,
  'f96837659e1d7747a10c718fb51c6e083c1f0ee83755c03b6d75d250cc77d081'
    AS feature_snapshot_id,
  'layerwise_online_v0_1' AS score_version,
  '64659d0e185d0add1316aa6b50b1ae4e3006069481a5c2be4df200afed6c2d1c'
    AS model_contract_sha256,
  '2202eb2a159f939bb5c8b04a783c264b122567335bd18ad85784b1533f9b1982'
    AS agent_contract_sha256,
  '634ec260599dd389bd58807ed597733c1cdf176a22caa457c7a313ec131252ca'
    AS score_sql_sha256,
  @git_head AS git_head,
  @repository_state AS repository_state,
  ['food_market_only', 'sewer_system_type_only'] AS included_variants,
  ['unused_public_building_address_point_overlay'] AS excluded_overlays,
  'DENY' AS raw_outcome_access_before_freeze;
