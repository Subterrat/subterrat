import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class SewerMetricsV02ContractTest(unittest.TestCase):
    def test_sewer_v0_2_is_a_gated_future_challenger(self):
        contract = json.loads(
            (ROOT / "contracts" / "sewer_metrics_v0_2_candidate.json").read_text(
                encoding="utf-8"
            )
        )
        self.assertEqual(contract["version_status"], "DRAFT_DATA_GATED_NOT_FROZEN")
        self.assertFalse(
            contract["outcome_policy"][
                "existing_889_reports_allowed_for_selection_or_tuning"
            ]
        )
        self.assertFalse(contract["variant_policy"]["composite_allowed_now"])
        self.assertFalse(
            contract["variant_policy"]["dynamic_reweighting_for_missing_metrics"]
        )
        self.assertIn(
            "manhole_depth_as_pipe_depth",
            contract["forbidden_proxies"],
        )
        self.assertEqual(
            contract["cell_policy"]["reported_pipe_length_role"],
            "QA_ONLY_GEOMETRY_DERIVED_LENGTH_IS_CANONICAL",
        )

    def test_bigquery_pipeline_materializes_only_independent_candidates(self):
        materialize_sql = (
            ROOT / "sql" / "structural" / "10_materialize_sewer_metrics_v0_2.sql"
        ).read_text(encoding="utf-8")
        ranking_sql = (
            ROOT / "sql" / "structural" / "11_rank_sewer_metrics_v0_2.sql"
        ).read_text(encoding="utf-8")
        quality_sql = (
            ROOT / "sql" / "structural" / "12_sewer_metrics_v0_2_quality.sql"
        ).read_text(encoding="utf-8")

        self.assertIn("ST_LENGTH(ST_INTERSECTION", materialize_sql)
        self.assertIn("MISSING_VALUES_REMAIN_NULL", materialize_sql)
        self.assertIn("sanitary_system_record_share", materialize_sql)
        for metric_id in (
            "sewer_system_type",
            "surface_elevation",
            "connected_pipe_diameter",
            "connected_pipe_depth",
            "connected_pipe_age",
        ):
            self.assertIn(metric_id, ranking_sql)
        self.assertIn("OUTCOME_FREE_NOT_FROZEN", ranking_sql)
        self.assertIn(
            "BLOCKED_METRICS_HAVE_DIAGNOSTIC_PERCENTILE_NOT_MODEL_SCORE",
            ranking_sql,
        )
        self.assertIn("diagnostic_percentile", ranking_sql)
        self.assertIn("metric_gate_state LIKE 'PASS_%'", ranking_sql)
        self.assertNotIn("sewer_paper_composite_v0_2", ranking_sql)
        self.assertIn("FALSE AS composite_allowed_now", quality_sql)

    def test_bigquery_load_schema_matches_required_export_fields(self):
        schema = json.loads(
            (ROOT / "contracts" / "bigquery_sanitary_pipe_v0_2_schema.json")
            .read_text(encoding="utf-8")
        )
        fields = {field["name"]: field for field in schema}
        self.assertEqual(fields["source_snapshot_id"]["mode"], "REQUIRED")
        self.assertEqual(fields["segment_id"]["mode"], "REQUIRED")
        self.assertEqual(fields["quality_flags"]["mode"], "REPEATED")
        self.assertIn("geometry_wkt_wgs84", fields)


if __name__ == "__main__":
    unittest.main()
