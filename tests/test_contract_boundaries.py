import json
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class ContractBoundaryTest(unittest.TestCase):
    def test_rat_radar_is_validation_only(self):
        contract = json.loads(
            (ROOT / "contracts" / "structural_score_v0_1.json").read_text(
                encoding="utf-8"
            )
        )
        policy = contract["outcome_policy"]
        self.assertEqual(policy["rat_radar_role"], "VALIDATION_ONLY_AFTER_T0_FREEZE")
        self.assertIn("training", policy["forbidden_uses"])
        self.assertIn("label", policy["forbidden_uses"])

    def test_layerwise_benchmark_does_not_wait_for_all_layers(self):
        contract = json.loads(
            (ROOT / "contracts" / "structural_score_v0_1.json").read_text(
                encoding="utf-8"
            )
        )
        self.assertEqual(
            contract["experiment_mode"],
            "ONLINE_FEATURE_ONLY_LAYERWISE_BENCHMARK",
        )
        self.assertFalse(
            contract["layerwise_policy"]["wait_for_all_feature_groups"]
        )
        self.assertTrue(
            contract["layerwise_policy"]["create_variant_when_layer_has_scored_cells"]
        )
        self.assertEqual(
            contract["selection_tie_policy"],
            "INCLUDE_ALL_THRESHOLD_TIES_AND_REPORT_ACTUAL_AREA_SHARE",
        )
        variants = {
            variant["variant_id"]: variant for variant in contract["variants"]
        }
        self.assertEqual(
            variants["abandoned_building_only"]["current_state"],
            "PROVISIONAL_OVERLAY_NOT_CITYWIDE_FEATURE",
        )

    def test_hotspot_model_has_no_fitted_training_path(self):
        contract = json.loads(
            (ROOT / "contracts" / "structural_score_v0_1.json").read_text(
                encoding="utf-8"
            )
        )
        self.assertEqual(contract["model_kind"], "DETERMINISTIC_HOTSPOT_RANKING")
        self.assertEqual(contract["training_mode"], "NO_SUPERVISED_TRAINING")
        self.assertFalse(contract["fitted_training_job_allowed"])
        self.assertFalse(contract["llm_weight_or_score_adjustment_allowed"])

    def test_evidence_agent_cannot_train_or_read_unfrozen_outcome(self):
        contract = json.loads(
            (ROOT / "contracts" / "evidence_agent_v0_1.json").read_text(
                encoding="utf-8"
            )
        )
        forbidden = set(contract["forbidden_capabilities"])
        self.assertIn("fit_or_train_model", forbidden)
        self.assertIn("read_validation_outcome_before_freeze", forbidden)
        self.assertEqual(contract["outcome_access"]["before_t0_freeze"], "DENY")
        self.assertEqual(contract["outcome_access"]["raw_report_points"], "DENY")

    def test_structural_sql_has_no_outcome_table_reference(self):
        forbidden_identifiers = (
            "approved_rat_reports",
            "rat_radar_reports",
            "report_status_events",
            "subterrat_t1_vault",
            "subterrat_evaluation",
        )
        for sql_path in sorted((ROOT / "sql" / "structural").glob("*.sql")):
            sql = sql_path.read_text(encoding="utf-8").lower()
            for identifier in forbidden_identifiers:
                self.assertNotIn(identifier, sql, f"{identifier} found in {sql_path}")

    def test_validation_sql_cannot_create_a_model(self):
        for sql_path in sorted((ROOT / "sql" / "validation").glob("*.sql")):
            sql = sql_path.read_text(encoding="utf-8").lower()
            self.assertNotIn("create model", sql, str(sql_path))
            self.assertNotIn("create or replace model", sql, str(sql_path))

    def test_retrospective_renderer_filters_and_anonymizes_rows(self):
        from scripts.render_rat_radar_retrospective_sql import render_sql

        with tempfile.TemporaryDirectory() as directory:
            csv_path = Path(directory) / "reports.csv"
            csv_path.write_text(
                "通報時間,類型,地點,狀態,說明,照片網址,緯度,經度\n"
                "2026-05-01 10:00,鼠蹤,臺北市 大安區,已審核,secret,,25.03,121.54\n"
                "2026-05-01 11:00,鼠蹤,新北市 板橋區,已審核,excluded,,25.01,121.46\n"
                "2026-05-01 12:00,毒餌,臺北市 大安區,已審核,excluded,,25.03,121.54\n",
                encoding="utf-8",
            )
            sql = render_sql(csv_path)
        self.assertIn("VALIDATION_ONLY_NOT_TRAINING", sql)
        self.assertIn("1 AS denominator", sql)
        self.assertNotIn("secret", sql)
        self.assertNotIn("excluded", sql)
        self.assertNotIn("25.03", sql)
        self.assertNotIn("121.54", sql)

    def test_structural_sql_cannot_create_a_model(self):
        for sql_path in sorted((ROOT / "sql" / "structural").glob("*.sql")):
            sql = sql_path.read_text(encoding="utf-8").lower()
            self.assertNotIn("create model", sql, str(sql_path))
            self.assertNotIn("create or replace model", sql, str(sql_path))

    def test_layerwise_score_is_not_probability(self):
        sql = (
            ROOT / "sql" / "structural" / "03_layerwise_score_candidates.sql"
        ).read_text(encoding="utf-8")
        self.assertIn("LAYER_SCORE_NOT_PROBABILITY", sql)
        self.assertIn("food_market_only", sql)
        self.assertIn("sewer_system_type_only", sql)
        self.assertIn("PROVISIONAL_OVERLAY_NOT_RANKED", sql)
        self.assertIn("INCLUDE_ALL_THRESHOLD_TIES", sql)

    def test_freeze_excludes_narrow_building_overlay(self):
        sql = (
            ROOT / "sql" / "structural" / "06_freeze_layer_scores_t0.sql"
        ).read_text(encoding="utf-8")
        self.assertIn("food_market_only", sql)
        self.assertIn("sewer_system_type_only", sql)
        self.assertIn("unused_public_building_address_point_overlay", sql)
        self.assertIn("@git_head", sql)
        self.assertIn("@repository_state", sql)
        self.assertNotIn("CREATE MODEL", sql.upper())

    def test_layerwise_validation_keeps_unmatched_outcomes_in_denominator(self):
        sql = (
            ROOT / "sql" / "validation" / "11_rat_radar_layerwise_post_freeze_only.sql"
        ).read_text(encoding="utf-8")
        self.assertIn("totals AS", sql)
        self.assertIn("totals.denominator", sql)
        self.assertIn("CROSS JOIN totals", sql)

    def test_map_payload_is_aggregate_and_not_probability(self):
        sql = (
            ROOT / "sql" / "structural" / "07_materialize_map_payload.sql"
        ).read_text(encoding="utf-8")
        self.assertIn("LAYER_SCORE_NOT_PROBABILITY", sql)
        self.assertIn("ST_ASGEOJSON", sql)
        self.assertIn("unused_public_building_address_point_count", sql)
        self.assertNotIn("source_address", sql)
        self.assertNotIn("approved_rat_reports", sql)

    def test_percentile_scores_do_not_break_feature_ties_with_cell_id(self):
        for sql_path in (
            ROOT / "sql" / "structural" / "03_layerwise_score_candidates.sql",
        ):
            sql = sql_path.read_text(encoding="utf-8").lower()
            self.assertNotIn(
                "percent_rank() over (order by food_market_sites_per_km2, cell_id)",
                sql,
            )
            self.assertNotIn(
                "percent_rank() over (order by sanitary_system_record_share, cell_id)",
                sql,
            )


if __name__ == "__main__":
    unittest.main()
