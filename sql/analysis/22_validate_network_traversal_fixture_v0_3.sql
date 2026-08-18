-- Read-only BigQuery fixture proving A-B-C traversal does not create A-C and
-- reversed source orientation preserves the canonical unordered link set.
-- Live validation job:
-- devjam26aug17tpe-1270:US.bquxjob_342ee2d_1a011b1d0e4
-- Both orientations produced only (1,2) and (2,3), with identical SHA256:
-- 0351298153585aa3b3c57b02a15ca166edd3e7b6f5cce8a1e898cf2f8e65f20a

WITH cells AS (
  SELECT * FROM UNNEST([
    STRUCT(1 AS cell_id, ST_GEOGFROMTEXT('POLYGON((121.50 25.00,121.51 25.00,121.51 25.01,121.50 25.01,121.50 25.00))') AS geom),
    STRUCT(2 AS cell_id, ST_GEOGFROMTEXT('POLYGON((121.51 25.00,121.52 25.00,121.52 25.01,121.51 25.01,121.51 25.00))') AS geom),
    STRUCT(3 AS cell_id, ST_GEOGFROMTEXT('POLYGON((121.52 25.00,121.53 25.00,121.53 25.01,121.52 25.01,121.52 25.00))') AS geom)
  ])
),
segments AS (
  SELECT 'forward' AS orientation, ST_GEOGFROMTEXT('LINESTRING(121.50 25.005,121.53 25.005)') AS line
  UNION ALL
  SELECT 'reverse', ST_GEOGFROMTEXT('LINESTRING(121.53 25.005,121.50 25.005)')
),
fragments AS (
  SELECT
    segment.orientation,
    cell.cell_id,
    segment.line,
    fragment,
    ROUND(CAST(LEAST(
      ST_LINELOCATEPOINT(segment.line, ST_POINTN(fragment, 1)),
      ST_LINELOCATEPOINT(segment.line, ST_POINTN(fragment, ST_NUMPOINTS(fragment)))
    ) AS BIGNUMERIC), 15, 'ROUND_HALF_EVEN') AS interval_low,
    ROUND(CAST(GREATEST(
      ST_LINELOCATEPOINT(segment.line, ST_POINTN(fragment, 1)),
      ST_LINELOCATEPOINT(segment.line, ST_POINTN(fragment, ST_NUMPOINTS(fragment)))
    ) AS BIGNUMERIC), 15, 'ROUND_HALF_EVEN') AS interval_high
  FROM segments AS segment
  JOIN cells AS cell ON ST_INTERSECTS(segment.line, cell.geom)
  CROSS JOIN UNNEST(ST_DUMP(ST_INTERSECTION(segment.line, cell.geom), 1)) AS fragment
  WHERE ST_LENGTH(fragment) > 0
),
sequence AS (
  SELECT
    orientation,
    cell_id,
    ROW_NUMBER() OVER (
      PARTITION BY orientation
      ORDER BY interval_low, interval_high, cell_id
    ) AS traversal_ordinal
  FROM fragments
),
adjacent AS (
  SELECT
    orientation,
    cell_id,
    LEAD(cell_id) OVER (
      PARTITION BY orientation ORDER BY traversal_ordinal
    ) AS next_cell_id
  FROM sequence
),
links AS (
  SELECT
    orientation,
    LEAST(cell_id, next_cell_id) AS from_cell_id,
    GREATEST(cell_id, next_cell_id) AS to_cell_id
  FROM adjacent
  WHERE next_cell_id IS NOT NULL AND cell_id != next_cell_id
)
SELECT
  orientation,
  ARRAY_AGG(
    STRUCT(from_cell_id, to_cell_id)
    ORDER BY from_cell_id, to_cell_id
  ) AS canonical_links,
  LOWER(TO_HEX(SHA256(CAST(STRING_AGG(
    CONCAT(CAST(from_cell_id AS STRING), ':', CAST(to_cell_id AS STRING)),
    ',' ORDER BY from_cell_id, to_cell_id
  ) AS BYTES)))) AS link_set_hash
FROM links
GROUP BY orientation
ORDER BY orientation;
