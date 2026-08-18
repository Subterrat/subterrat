-- Outcome-free structural comparison of v0.2 sewer diagnostics with the
-- frozen v0.1 food layer. This query neither selects a model nor reads Rat Radar.

WITH
food AS (
  SELECT
    cell_id,
    eligible_area_m2,
    food_score,
    food_top_area
  FROM `devjam26aug17tpe-1270.subterrat_predictions.map_hotspot_cells_t0`
),
city AS (
  SELECT SUM(eligible_area_m2) AS total_city_area_m2
  FROM food
),
metric_rows AS (
  SELECT
    variant_id,
    cell_id,
    eligible_area_m2,
    diagnostic_percentile AS sewer_score,
    diagnostic_top_10pct_area_flag AS sewer_top_area
  FROM
    `devjam26aug17tpe-1270.subterrat_predictions.sewer_metric_rankings_v0_2_candidate`
),
metric_comparison AS (
  SELECT
    metric_rows.variant_id,
    COUNTIF(metric_rows.sewer_score IS NOT NULL) AS common_scored_cells,
    SAFE_DIVIDE(
      COUNTIF(metric_rows.sewer_score IS NOT NULL), COUNT(*)
    ) AS scored_cell_share,
    SAFE_DIVIDE(
      SUM(IF(metric_rows.sewer_score IS NOT NULL, food.eligible_area_m2, 0)),
      city.total_city_area_m2
    ) AS scored_area_share,
    CORR(food.food_score, metric_rows.sewer_score) AS rank_score_correlation,
    SAFE_DIVIDE(
      SUM(IF(metric_rows.sewer_top_area, food.eligible_area_m2, 0)),
      city.total_city_area_m2
    ) AS sewer_selected_area_share,
    SAFE_DIVIDE(
      SUM(IF(food.food_top_area, food.eligible_area_m2, 0)),
      city.total_city_area_m2
    ) AS food_selected_area_share,
    SAFE_DIVIDE(
      SUM(IF(
        metric_rows.sewer_top_area AND food.food_top_area,
        food.eligible_area_m2,
        0
      )),
      SUM(IF(
        metric_rows.sewer_top_area OR food.food_top_area,
        food.eligible_area_m2,
        0
      ))
    ) AS top_area_jaccard
  FROM metric_rows
  JOIN food USING (cell_id)
  CROSS JOIN city
  GROUP BY metric_rows.variant_id, city.total_city_area_m2
),
sewer_pivot AS (
  SELECT
    cell_id,
    ANY_VALUE(eligible_area_m2) AS eligible_area_m2,
    COUNTIF(diagnostic_percentile IS NOT NULL) AS available_metric_count,
    MAX(IF(variant_id = 'sewer_system_type', diagnostic_percentile, NULL))
      AS system_type,
    MAX(IF(variant_id = 'surface_elevation', diagnostic_percentile, NULL))
      AS elevation,
    MAX(IF(variant_id = 'connected_pipe_diameter', diagnostic_percentile, NULL))
      AS diameter,
    MAX(IF(variant_id = 'connected_pipe_depth', diagnostic_percentile, NULL))
      AS depth,
    MAX(IF(variant_id = 'connected_pipe_age', diagnostic_percentile, NULL))
      AS age
  FROM
    `devjam26aug17tpe-1270.subterrat_predictions.sewer_metric_rankings_v0_2_candidate`
  GROUP BY cell_id
),
composite_base AS (
  SELECT
    cell_id,
    eligible_area_m2,
    IF(
      available_metric_count = 5,
      (system_type + elevation + diameter + depth + age) / 5,
      NULL
    ) AS sewer_score
  FROM sewer_pivot
),
composite_area_ranked AS (
  SELECT
    *,
    SUM(IF(sewer_score IS NULL, 0, eligible_area_m2)) OVER (
      ORDER BY sewer_score DESC NULLS LAST, cell_id
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_scored_area_m2,
    SUM(eligible_area_m2) OVER () AS total_city_area_m2
  FROM composite_base
),
composite_threshold AS (
  SELECT MIN(sewer_score) AS threshold_score
  FROM composite_area_ranked
  WHERE
    sewer_score IS NOT NULL
    AND cumulative_scored_area_m2 - eligible_area_m2 < total_city_area_m2 * 0.10
),
composite AS (
  SELECT
    composite_area_ranked.*,
    sewer_score IS NOT NULL AND sewer_score >= threshold_score AS sewer_top_area
  FROM composite_area_ranked
  CROSS JOIN composite_threshold
),
composite_comparison AS (
  SELECT
    'sewer_attribute_index_v0_2_complete_case' AS variant_id,
    COUNTIF(composite.sewer_score IS NOT NULL) AS common_scored_cells,
    SAFE_DIVIDE(
      COUNTIF(composite.sewer_score IS NOT NULL), COUNT(*)
    ) AS scored_cell_share,
    SAFE_DIVIDE(
      SUM(IF(composite.sewer_score IS NOT NULL, food.eligible_area_m2, 0)),
      city.total_city_area_m2
    ) AS scored_area_share,
    CORR(food.food_score, composite.sewer_score) AS rank_score_correlation,
    SAFE_DIVIDE(
      SUM(IF(composite.sewer_top_area, food.eligible_area_m2, 0)),
      city.total_city_area_m2
    ) AS sewer_selected_area_share,
    SAFE_DIVIDE(
      SUM(IF(food.food_top_area, food.eligible_area_m2, 0)),
      city.total_city_area_m2
    ) AS food_selected_area_share,
    SAFE_DIVIDE(
      SUM(IF(
        composite.sewer_top_area AND food.food_top_area,
        food.eligible_area_m2,
        0
      )),
      SUM(IF(
        composite.sewer_top_area OR food.food_top_area,
        food.eligible_area_m2,
        0
      ))
    ) AS top_area_jaccard
  FROM composite
  JOIN food USING (cell_id)
  CROSS JOIN city
  GROUP BY city.total_city_area_m2
)
SELECT *
FROM metric_comparison
UNION ALL
SELECT *
FROM composite_comparison
ORDER BY variant_id;
