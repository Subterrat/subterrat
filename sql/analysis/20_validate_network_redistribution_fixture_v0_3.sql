-- Read-only BigQuery fixture for the elementary-edge and canonical-decimal
-- primitives used by the v0.3 synthetic network redistribution challenger.
-- Live validation job (US, no table bytes):
-- devjam26aug17tpe-1270:US.bquxjob_4911568a_1a011a14187

WITH sample AS (
  SELECT ST_GEOGFROMTEXT(
    'LINESTRING(121.5 25.0, 121.51 25.0, 121.52 25.01)'
  ) AS line
),
edge AS (
  SELECT
    line,
    ST_MAKELINE(ST_POINTN(line, 1), ST_POINTN(line, 2)) AS elementary_edge
  FROM sample
),
fragment_row AS (
  SELECT
    line,
    elementary_edge,
    ST_LINESUBSTRING(elementary_edge, 0.25, 0.75) AS fragment
  FROM edge
)
SELECT
  ST_ISEMPTY(line) AS is_empty,
  ST_NUMPOINTS(line) AS point_count,
  ST_LENGTH(elementary_edge) > 0 AS positive_edge,
  ROUND(CAST(ST_LINELOCATEPOINT(
    elementary_edge,
    ST_POINTN(fragment, 1)
  ) AS BIGNUMERIC), 15, 'ROUND_HALF_EVEN') AS interval_low,
  ROUND(CAST(ST_LINELOCATEPOINT(
    elementary_edge,
    ST_POINTN(fragment, ST_NUMPOINTS(fragment))
  ) AS BIGNUMERIC), 15, 'ROUND_HALF_EVEN') AS interval_high,
  ROUND(
    CAST('0.1250000000005' AS BIGNUMERIC),
    12,
    'ROUND_HALF_EVEN'
  ) AS half_even_probe
FROM fragment_row;

-- Observed live result:
-- is_empty=false, point_count=3, positive_edge=true,
-- interval_low=0.250000000000344,
-- interval_high=0.750000000000514,
-- half_even_probe=0.125.
