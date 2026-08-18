import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class HotspotScenarioV03ContractTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.contract = json.loads(
            (ROOT / "contracts" / "hotspot_scenario_v0_3_candidate.json").read_text(
                encoding="utf-8"
            )
        )

    def test_is_scenario_not_probability_or_training(self) -> None:
        self.assertEqual(
            self.contract["model_kind"],
            "DETERMINISTIC_ORDINAL_INTERNAL_SIMULATION_NOT_PROBABILITY",
        )
        self.assertFalse(
            self.contract["outcome_policy"][
                "existing_889_reports_allowed_for_selection_or_tuning"
            ]
        )
        self.assertIn("training", self.contract["outcome_policy"]["forbidden_uses"])
        self.assertFalse(
            self.contract["spatial_scenario"]["biological_claim_allowed"]
        )

    def test_equal_group_weights_are_pre_registered(self) -> None:
        weights = [group["group_weight"] for group in self.contract["feature_groups"]]
        self.assertAlmostEqual(sum(weights), 1.0)
        self.assertEqual(len(set(weights)), 1)
        self.assertEqual(
            self.contract["score_rule"]["missing_group_action"],
            "NULL_NOT_DYNAMIC_REWEIGHT",
        )

    def test_sewer_transform_directions_match_v0_2_sql(self) -> None:
        transforms = self.contract["component_transformations"]
        self.assertIn("diameter descending", transforms["sewer_pipe_diameter"])
        self.assertIn("depth descending", transforms["sewer_depth"])
        self.assertIn("elevation ascending", transforms["sewer_elevation"])

    def test_urban_renewal_is_not_abandoned_building(self) -> None:
        source = self.contract["urban_renewal_source"]
        self.assertIn("not evidence of physical disturbance", source["construct_boundary"])
        self.assertTrue(source["source_reuse_license_state"].startswith("BLOCKED_"))
        self.assertEqual(source["primary_inclusion"]["source_rows"], 250)
        self.assertEqual(
            source["primary_inclusion"]["unique_source_record_numbers"], 248
        )
        self.assertEqual(
            source["pre_review_live_analysis_cell_match"][
                "matched_source_rows_at_150m"
            ],
            249,
        )
        self.assertEqual(
            self.contract["spatial_scenario"]["primary_variant"],
            "approved_rebuilding_admin_site_cell_footprint_buffer_150m",
        )

    def test_public_release_remains_blocked(self) -> None:
        policy = self.contract["publication_policy"]
        self.assertFalse(policy["public_release_allowed_now"])
        self.assertFalse(policy["operational_use_allowed_now"])
        self.assertIn("NO_TRUSTED_RESULT", policy["required_limitation_codes"])
        self.assertIn(
            "V0_2_SEWER_GATES_INCOMPLETE", policy["required_limitation_codes"]
        )
        self.assertIn(
            "URBAN_RENEWAL_ADMIN_SITE_COVERAGE_247_OF_248",
            policy["required_limitation_codes"],
        )
        self.assertEqual(
            self.contract["urban_renewal_source"]
            ["live_admin_site_analysis_cell_match"]["matched_sites_at_150m"],
            247,
        )

    def test_reviewed_state_contract_is_explicit(self) -> None:
        state = self.contract["state_contract"]
        self.assertEqual(state["specification_state"], "PENDING_COMMITTED_LOCK")
        self.assertEqual(state["use_state"], "INTERNAL_SIMULATION_ONLY")
        self.assertEqual(state["evidence_state"], "NO_TRUSTED_RESULT")
        self.assertEqual(state["operational_use"], "PROHIBITED")

    def test_concordance_uses_only_composite_and_food_baseline(self) -> None:
        diagnostic_variants = self.contract["outcome_free_diagnostic_variants"]
        self.assertEqual(
            diagnostic_variants,
            [
                "food_market_only_v0_1",
                "sewer_system_type_only_v0_1",
                "sewer_attribute_index_v0_2_complete_case",
                "approved_rebuilding_admin_site_cell_footprint_buffer_0m",
                "approved_rebuilding_admin_site_cell_footprint_buffer_150m",
                "approved_rebuilding_admin_site_cell_footprint_buffer_300m",
                "v0_3_equal_group_internal_simulation_r150",
            ],
        )
        self.assertIn(
            "pre-lock QA and frontend preview only",
            self.contract["outcome_free_diagnostic_variant_policy"],
        )
        self.assertEqual(
            self.contract["comparison_variants"],
            [
                "v0_3_equal_group_internal_simulation_r150",
                "food_market_only_v0_1",
            ],
        )
        evaluation = self.contract["concordance_evaluation"]
        self.assertEqual(
            evaluation["evaluated_model_variant"],
            "v0_3_equal_group_internal_simulation_r150",
        )
        self.assertEqual(evaluation["baseline_variant"], "food_market_only_v0_1")
        self.assertEqual(
            evaluation["result_granularity"],
            "one composite result row with food-only baseline columns per evaluation scope",
        )
        self.assertFalse(evaluation["diagnostic_variants_evaluated_separately"])
        self.assertFalse(evaluation["component_map_outcome_comparison_allowed"])
        self.assertFalse(evaluation["selection_from_results_allowed"])
        self.assertFalse(evaluation["component_attribution_allowed"])
        self.assertIn("same result row", evaluation["primary_citywide_comparison"])
        self.assertEqual(
            self.contract["publication_policy"]["frontend_component_layers"],
            [
                "food_market",
                "sewer_attribute_index",
                "approved_rebuilding_admin_site_cell_footprint_buffer_150m",
            ],
        )


if __name__ == "__main__":
    unittest.main()
