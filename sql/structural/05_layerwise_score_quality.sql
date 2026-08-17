SELECT
  variant_id,
  ANY_VALUE(feature_snapshot_id) AS feature_snapshot_id,
  COUNT(*) AS total_city_cells,
  COUNTIF(layer_score IS NOT NULL) AS scored_cells,
  SAFE_DIVIDE(COUNTIF(layer_score IS NOT NULL), COUNT(*)) AS scored_cell_share,
  SUM(eligible_area_m2) AS total_city_area_m2,
  SUM(IF(layer_score IS NOT NULL, eligible_area_m2, 0)) AS scored_area_m2,
  SAFE_DIVIDE(
    SUM(IF(layer_score IS NOT NULL, eligible_area_m2, 0)),
    SUM(eligible_area_m2)
  ) AS scored_area_share,
  SUM(IF(top_10pct_area_flag, eligible_area_m2, 0)) AS selected_area_m2,
  SAFE_DIVIDE(
    SUM(IF(top_10pct_area_flag, eligible_area_m2, 0)),
    SUM(eligible_area_m2)
  ) AS selected_area_share,
  ANY_VALUE(candidate_state) AS candidate_state,
  ANY_VALUE(selection_threshold_score) AS selection_threshold_score,
  ANY_VALUE(selection_tie_policy) AS selection_tie_policy,
  ANY_VALUE(evidence_state) AS evidence_state,
  ANY_VALUE(score_semantics) AS score_semantics
FROM `devjam26aug17tpe-1270.subterrat_predictions.layer_scores_t0_candidate`
GROUP BY variant_id
ORDER BY variant_id;
