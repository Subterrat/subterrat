-- Read-only temporary BigQuery fixture for the canonical recurrence.
-- Live validation job:
-- devjam26aug17tpe-1270:US.bquxjob_429b7f6b_1a011adfe17
-- Observed mass is exactly 1 at iterations 0, 1, and 2.
-- Iteration 1 states: 0.481875, 0.405, 0.113125.
-- Iteration 2 states: 0.4380703125, 0.428625, 0.1333046875.

DECLARE iteration_number INT64 DEFAULT 1;

CREATE TEMP TABLE seeds AS
SELECT * FROM UNNEST([
  STRUCT(1 AS cell_id, CAST('0.600000000000000000000000' AS BIGNUMERIC) AS source_seed),
  STRUCT(2 AS cell_id, CAST('0.300000000000000000000000' AS BIGNUMERIC) AS source_seed),
  STRUCT(3 AS cell_id, CAST('0.100000000000000000000000' AS BIGNUMERIC) AS source_seed)
]);

CREATE TEMP TABLE transitions AS
SELECT * FROM UNNEST([
  STRUCT(1 AS from_cell_id, 1 AS to_cell_id, CAST('0.650000000000000000000000' AS BIGNUMERIC) AS transition_value),
  STRUCT(1 AS from_cell_id, 2 AS to_cell_id, CAST('0.350000000000000000000000' AS BIGNUMERIC) AS transition_value),
  STRUCT(2 AS from_cell_id, 1 AS to_cell_id, CAST('0.175000000000000000000000' AS BIGNUMERIC) AS transition_value),
  STRUCT(2 AS from_cell_id, 2 AS to_cell_id, CAST('0.650000000000000000000000' AS BIGNUMERIC) AS transition_value),
  STRUCT(2 AS from_cell_id, 3 AS to_cell_id, CAST('0.175000000000000000000000' AS BIGNUMERIC) AS transition_value),
  STRUCT(3 AS from_cell_id, 2 AS to_cell_id, CAST('0.350000000000000000000000' AS BIGNUMERIC) AS transition_value),
  STRUCT(3 AS from_cell_id, 3 AS to_cell_id, CAST('0.650000000000000000000000' AS BIGNUMERIC) AS transition_value)
]);

ASSERT (
  SELECT MAX(ABS(row_sum - CAST(1 AS BIGNUMERIC))) <= CAST('0.000000000001' AS BIGNUMERIC)
  FROM (
    SELECT from_cell_id, SUM(transition_value) AS row_sum
    FROM transitions
    GROUP BY from_cell_id
  )
) AS 'fixture transition is not row stochastic';

CREATE TEMP TABLE state_work AS
SELECT 0 AS abstract_iteration, cell_id, source_seed AS unit_mass_state
FROM seeds;
CREATE TEMP TABLE all_states AS SELECT * FROM state_work;

WHILE iteration_number <= 2 DO
  CREATE OR REPLACE TEMP TABLE next_state AS
  WITH propagated AS (
    SELECT
      transition.to_cell_id AS cell_id,
      SUM(ROUND(
        CAST('0.75' AS BIGNUMERIC)
          * prior.unit_mass_state
          * transition.transition_value,
        30,
        'ROUND_HALF_EVEN'
      )) AS propagated_mass
    FROM state_work AS prior
    JOIN transitions AS transition
      ON prior.cell_id = transition.from_cell_id
    GROUP BY transition.to_cell_id
  )
  SELECT
    iteration_number AS abstract_iteration,
    seed.cell_id,
    ROUND(
      ROUND(
        CAST('0.25' AS BIGNUMERIC) * seed.source_seed,
        30,
        'ROUND_HALF_EVEN'
      ) + propagated.propagated_mass,
      24,
      'ROUND_HALF_EVEN'
    ) AS unit_mass_state
  FROM seeds AS seed
  JOIN propagated USING (cell_id);

  INSERT INTO all_states SELECT * FROM next_state;
  CREATE OR REPLACE TEMP TABLE state_work AS SELECT * FROM next_state;
  SET iteration_number = iteration_number + 1;
END WHILE;

SELECT
  abstract_iteration,
  ROUND(SUM(unit_mass_state), 24, 'ROUND_HALF_EVEN') AS state_mass,
  ARRAY_AGG(
    STRUCT(cell_id, unit_mass_state)
    ORDER BY cell_id
  ) AS cell_states
FROM all_states
GROUP BY abstract_iteration
ORDER BY abstract_iteration;
