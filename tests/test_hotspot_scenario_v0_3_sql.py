import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class HotspotScenarioV03SqlTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.sql = {
            path.name: path.read_text(encoding="utf-8")
            for path in (ROOT / "sql" / "structural").glob("1[3-9]_*.sql")
        }
        cls.all_sql = "\n".join(cls.sql.values()).lower()
        cls.executable_sql = re.sub(r"--[^\n]*", "", cls.all_sql)

    def test_pipeline_has_expected_steps(self) -> None:
        self.assertEqual(len(self.sql), 7)
        for table in (
            "urban_renewal_point_v0_3_raw",
            "urban_renewal_point_v0_3_candidate",
            "urban_renewal_admin_site_v0_3_internal_simulation",
            "urban_renewal_admin_site_metrics_v0_3_internal_simulation",
            "hotspot_scenarios_v0_3_internal_simulation",
            "hotspot_scenario_quality_v0_3_internal_simulation",
            "map_hotspot_cells_v0_3_internal_simulation",
            "hotspot_scenarios_v0_3_locked_internal_simulation",
            "hotspot_scenario_lock_manifest_v0_3",
        ):
            self.assertIn(table, self.all_sql)

    def test_sql_never_reads_outcome_tables(self) -> None:
        forbidden = (
            "rat_radar",
            "approved_rat_reports",
            "subterrat_evaluation",
            "subterrat_t1_vault",
            "ml.predict",
            "create model",
        )
        for term in forbidden:
            self.assertNotIn(term, self.executable_sql)

    def test_primary_formula_and_radii_are_fixed(self) -> None:
        metric_sql = self.sql["15_materialize_urban_renewal_metrics_v0_3.sql"]
        scenario_sql = self.sql["16_build_hotspot_scenarios_v0_3.sql"]
        self.assertIn("UNNEST([0, 150, 300])", metric_sql)
        self.assertIn("SELECT DISTINCT source_snapshot_id", metric_sql)
        self.assertNotIn("ANY_VALUE(source_snapshot_id)", metric_sql)
        self.assertIn("COUNT(*) = 248", metric_sql)
        self.assertIn("admin_site_count = 0", metric_sql)
        self.assertIn("CELL_FOOTPRINT_BUFFER", metric_sql)
        self.assertIn("+ sewer_attribute_index", scenario_sql)
        self.assertIn("+ approved_rebuilding_admin_site_r150", scenario_sql)
        self.assertIn("/ 3", scenario_sql)
        self.assertIn("BLOCKED_INTERNAL_SIMULATION_V0_2_GATES_INCOMPLETE", scenario_sql)
        self.assertIn("@specification_git_head", scenario_sql)
        self.assertIn("@review_receipt_sha256", scenario_sql)
        self.assertIn("rank_within_scoreable_support", scenario_sql)
        self.assertIn("NULL", scenario_sql)

    def test_bigquery_export_minimizes_precise_text_fields(self) -> None:
        raw_sql = self.sql["13_create_urban_renewal_v0_3_raw.sql"]
        curated_sql = self.sql["14_merge_and_curate_urban_renewal_v0_3.sql"]
        for forbidden in ("location_text", "project_name", "source_payload_json"):
            self.assertNotIn(forbidden, raw_sql)
            self.assertNotIn(forbidden, curated_sql)

    def test_serving_payload_cannot_claim_probability_or_release(self) -> None:
        payload_sql = self.sql["18_materialize_map_payload_v0_3.sql"]
        self.assertIn("SPECIFICATION_LOCKED_INTERNAL_SIMULATION_ONLY", payload_sql)
        self.assertIn("ORDINAL_SIMULATION_INDEX_NOT_PROBABILITY", payload_sql)
        self.assertIn("NO_TRUSTED_RESULT", payload_sql)
        self.assertIn("OPERATIONAL_USE_PROHIBITED", payload_sql)
        self.assertIn(
            "URBAN_RENEWAL_ADMIN_SITE_COVERAGE_247_OF_248", payload_sql
        )
        self.assertIn("CAST(NULL AS FLOAT64) AS calibrated_probability", payload_sql)
        self.assertNotIn("location_text", payload_sql)
        self.assertNotIn("project_name", payload_sql)

    def test_retrospective_lock_reuses_exact_artifact_identity(self) -> None:
        lock_sql = self.sql["19_lock_hotspot_scenario_v0_3.sql"]
        for parameter in (
            "@specification_git_head",
            "@review_receipt_sha256",
            "@scenario_contract_sha256",
            "@scenario_sql_sha256",
            "@urban_renewal_source_snapshot_id",
        ):
            self.assertIn(parameter, lock_sql)
        self.assertIn(
            "LOCKED_AWAITING_ONE_SHOT_RETROSPECTIVE_CONCORDANCE", lock_sql
        )
        self.assertIn("NO_TRUSTED_RESULT", lock_sql)
        self.assertIn("PROHIBITED", lock_sql)

    def test_retrospective_lock_exposes_only_composite_and_baseline(self) -> None:
        lock_sql = self.sql["19_lock_hotspot_scenario_v0_3.sql"]
        expected_variants = {
            "v0_3_equal_group_internal_simulation_r150",
            "food_market_only_v0_1",
        }
        locked_rows = re.search(
            r"hotspot_scenarios_v0_3_locked_internal_simulation`\s*"
            r"CLUSTER BY variant_id, cell_id AS\s*SELECT.*?"
            r"WHERE variant_id IN \((.*?)\);",
            lock_sql,
            flags=re.DOTALL,
        )
        self.assertIsNotNone(locked_rows)
        self.assertEqual(
            set(re.findall(r"'([^']+)'", locked_rows.group(1))),
            expected_variants,
        )

        included_variants = re.search(
            r"@urban_renewal_source_snapshot_id AS "
            r"urban_renewal_source_snapshot_id,\s*\[(.*?)\]\s+"
            r"AS included_variants",
            lock_sql,
            flags=re.DOTALL,
        )
        self.assertIsNotNone(included_variants)
        self.assertEqual(
            set(re.findall(r"'([^']+)'", included_variants.group(1))),
            expected_variants,
        )
        self.assertIn("COUNT(*) = 3420 * 2", lock_sql)
        self.assertIn("COUNT(*) = 3420 * 7", lock_sql)
        self.assertIn("COUNT(*) = 7", lock_sql)
        for variant_id in expected_variants:
            self.assertRegex(
                lock_sql,
                rf"COUNTIF\([^)]*variant_id = '{variant_id}'[^)]*\) = 3420",
            )

    def test_frontend_components_are_not_outcome_comparison_variants(self) -> None:
        lock_sql = self.sql["19_lock_hotspot_scenario_v0_3.sql"]
        component_layers = re.search(
            r"AS included_variants,\s*\[(.*?)\]\s+"
            r"AS frontend_component_layers",
            lock_sql,
            flags=re.DOTALL,
        )
        self.assertIsNotNone(component_layers)
        self.assertEqual(
            set(re.findall(r"'([^']+)'", component_layers.group(1))),
            {
                "food_market",
                "sewer_attribute_index",
                "approved_rebuilding_admin_site_cell_footprint_buffer_150m",
            },
        )
        self.assertIn("'DENY' AS component_outcome_concordance", lock_sql)
        self.assertIn(
            "ANY_VALUE(component_outcome_concordance) = 'DENY'", lock_sql
        )
        self.assertIn(
            "v0_3_equal_group_internal_simulation_r150,food_market_only_v0_1",
            lock_sql,
        )
        self.assertIn(
            "food_market,sewer_attribute_index,"
            "approved_rebuilding_admin_site_cell_footprint_buffer_150m",
            lock_sql,
        )

    def test_structural_comparison_is_outcome_free(self) -> None:
        comparison_sql = (
            ROOT / "sql" / "analysis" / "01_compare_v0_2_sewer_to_food.sql"
        ).read_text(encoding="utf-8")
        executable_sql = re.sub(r"--[^\n]*", "", comparison_sql.lower())
        self.assertIn("sewer_attribute_index_v0_2_complete_case", comparison_sql)
        self.assertIn("top_area_jaccard", comparison_sql)
        self.assertIn("rank_score_correlation", comparison_sql)
        self.assertNotIn("rat_radar", executable_sql)
        self.assertNotIn("subterrat_evaluation", executable_sql)


if __name__ == "__main__":
    unittest.main()
