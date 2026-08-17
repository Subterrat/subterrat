import unittest
from datetime import datetime
from decimal import Decimal
from pathlib import Path

from services.hotspot_api.config import get_settings
from services.hotspot_api.repositories.v03_evaluation_repo import (
    _COLUMNS,
    V03EvaluationRepository,
)


def _row(tolerance_m: int) -> dict[str, object]:
    is_buffered = tolerance_m == 200
    return {
        "ecological_tolerance_m": tolerance_m,
        "tolerance_role": (
            "LITERATURE_ANCHORED_UPPER_BOUND"
            if is_buffered
            else "PRIMARY_EXACT_CELL"
        ),
        "report_denominator": 889,
        "v0_3_overlapping_report_count": 650 if is_buffered else 400,
        "v0_3_report_overlap_fraction": Decimal(
            "0.7311586051743532" if is_buffered else "0.4499437570303712"
        ),
        "v0_3_buffered_taipei_area_share": Decimal(
            "0.206605" if is_buffered else "0.10003238158061235"
        ),
        "v0_3_report_overlap_to_area_ratio": Decimal(
            "3.539" if is_buffered else "4.498"
        ),
        "food_overlapping_report_count": 686 if is_buffered else 447,
        "food_report_overlap_fraction": Decimal(
            "0.7716535433070866" if is_buffered else "0.5028121484814398"
        ),
        "food_buffered_taipei_area_share": Decimal(
            "0.2080" if is_buffered else "0.10000424835007789"
        ),
        "food_report_overlap_to_area_ratio": Decimal(
            "3.710" if is_buffered else "5.028"
        ),
        "difference_in_report_overlap_vs_food_v0_1": Decimal(
            "-0.0404949381327334" if is_buffered else "-0.0528683914510686"
        ),
        "distance_semantics": "SELECTED_CELL_FOOTPRINT_BUFFER_DISTANCE_METERS",
        "footprint_semantics": "BUFFERED_FOOTPRINT_AREA_SHARE_NOT_FIXED_TOP_10_PERCENT",
        "calculation_path": "BIGQUERY_GIS_AGGREGATE_ONLY",
        "evaluation_kind": "POST_LOCK_DESCRIPTIVE_SENSITIVITY",
        "outcome_role": "VALIDATION_ONLY_NOT_TRAINING",
        "evaluated_variant_id": "v0_3_equal_group_internal_simulation_r150",
        "baseline_variant_id": "food_market_only_v0_1",
        "specification_git_head": "a54ef1dd02c0d6ba692a8ed7a07fd9026686b64a",
        "source_csv_sha256": "b5f9f5223aa514bc3b02159f974efbb72e5cb75333384dde8a98f281305aa37a",
        "observed_from": datetime(2026, 5, 2, 23, 6),
        "observed_to": datetime(2026, 7, 8, 9, 56),
        "score_semantics": "REPORT_OVERLAP_FRACTION_NOT_PROBABILITY_OR_ACCURACY",
        "evidence_state": "NO_TRUSTED_RESULT",
        "use_state": "INTERNAL_RESEARCH_ONLY",
        "operational_use": "PROHIBITED",
        "public_release_ready": False,
        "literature_doi": "10.1071/WR11149",
        "literature_interpretation": "200m is a literature-anchored upper-bound sensitivity",
        "limitation_codes": [
            "DEVELOPMENT_EXPOSED_RETROSPECTIVE",
            "NOT_PROBABILITY_OR_ACCURACY",
        ],
    }


class _FakeGateway:
    def __init__(self, rows) -> None:
        self.rows = rows
        self.calls = []

    def query(self, sql, parameters=None):
        self.calls.append((sql, parameters))
        return self.rows


class V03EvaluationRepositoryTest(unittest.TestCase):
    def test_api_allowlist_matches_materialized_serving_columns(self) -> None:
        root = Path(__file__).resolve().parents[1]
        sql = (
            root
            / "sql"
            / "validation"
            / "24_materialize_hotspot_evaluation_serving_v0_3.sql"
        ).read_text(encoding="utf-8")
        for column in _COLUMNS:
            self.assertIn(column, sql)

    def test_settings_build_the_internal_evaluation_table_ref(self) -> None:
        settings = get_settings()
        self.assertEqual(
            settings.v03_evaluation_table_ref,
            "devjam26aug17tpe-1270.subterrat_predictions."
            "hotspot_evaluation_summary_v0_3_internal_simulation",
        )

    def test_reads_only_two_allowlisted_aggregate_rows(self) -> None:
        gateway = _FakeGateway([_row(0), _row(200)])
        repository = V03EvaluationRepository(
            gateway,
            "project.subterrat_predictions."
            "hotspot_evaluation_summary_v0_3_internal_simulation",
        )

        result = repository.get_summary()

        self.assertEqual(
            [row.ecological_tolerance_m for row in result.rows], [0, 200]
        )
        self.assertEqual(result.rows[1].v0_3_overlapping_report_count, 650)
        self.assertEqual(result.rows[1].food_overlapping_report_count, 686)
        self.assertEqual(result.evidence_state, "NO_TRUSTED_RESULT")
        self.assertEqual(result.use_state, "INTERNAL_RESEARCH_ONLY")
        self.assertEqual(result.operational_use, "PROHIBITED")
        self.assertFalse(result.public_release_ready)
        self.assertEqual(result.rows[0].observed_from, "2026-05-02T23:06:00")
        self.assertEqual(result.rows[0].literature_doi, "10.1071/WR11149")
        self.assertEqual(result.rows[1].literature_doi, "10.1071/WR11149")

        sql, parameters = gateway.calls[0]
        self.assertIsNone(parameters)
        self.assertNotIn("SELECT *", sql.upper())
        self.assertIn("ecological_tolerance_m IN (0, 200)", sql)
        self.assertIn("use_state = 'INTERNAL_RESEARCH_ONLY'", sql)
        self.assertIn("evidence_state = 'NO_TRUSTED_RESULT'", sql)
        self.assertIn("operational_use = 'PROHIBITED'", sql)
        self.assertIn("NOT public_release_ready", sql)
        self.assertIn("ORDER BY ecological_tolerance_m", sql)

    def test_select_allowlist_has_no_sensitive_location_or_identity_fields(self) -> None:
        forbidden = {
            "report_id",
            "cell_id",
            "latitude",
            "longitude",
            "geometry",
            "geojson",
            "address",
            "photo_url",
        }
        self.assertTrue(forbidden.isdisjoint(_COLUMNS))

    def test_fails_closed_without_exactly_zero_and_two_hundred_meter_rows(self) -> None:
        repository = V03EvaluationRepository(
            _FakeGateway([_row(200)]),
            "project.dataset.table",
        )

        with self.assertRaisesRegex(ValueError, "exactly the 0m and 200m rows"):
            repository.get_summary()


if __name__ == "__main__":
    unittest.main()
