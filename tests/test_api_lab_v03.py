import unittest
from dataclasses import replace

from fastapi.testclient import TestClient

from services.hotspot_api.config import get_settings
from services.hotspot_api.dependencies import (
    get_v03_cells_repository,
    get_v03_evaluation_repository,
)
from services.hotspot_api.public_app import app
from services.hotspot_api.schemas.lab_v03 import (
    V03EvaluationSummaryResponse,
    V03EvaluationSummaryRow,
    V03LabFeatureCollection,
)


class _RecordingV03Repo:
    def __init__(self) -> None:
        self.last_call = None

    def list_cells(self, bbox, limit, page_token):
        self.last_call = (bbox, limit, page_token)
        return V03LabFeatureCollection(features=[])


def _evaluation_row(tolerance_m: int) -> V03EvaluationSummaryRow:
    is_buffered = tolerance_m == 200
    return V03EvaluationSummaryRow(
        ecological_tolerance_m=tolerance_m,
        tolerance_role=(
            "LITERATURE_ANCHORED_UPPER_BOUND"
            if is_buffered
            else "PRIMARY_EXACT_CELL"
        ),
        report_denominator=889,
        v0_3_overlapping_report_count=650 if is_buffered else 400,
        v0_3_report_overlap_fraction=(
            0.7311586051743532 if is_buffered else 0.4499437570303712
        ),
        v0_3_buffered_taipei_area_share=(
            0.20658713471190893 if is_buffered else 0.10003238158061235
        ),
        v0_3_report_overlap_to_area_ratio=(
            3.5392262262312348 if is_buffered else 4.497981052943125
        ),
        food_overlapping_report_count=686 if is_buffered else 447,
        food_report_overlap_fraction=(
            0.7716535433070866 if is_buffered else 0.5028121484814398
        ),
        food_buffered_taipei_area_share=(
            0.20798403385198783 if is_buffered else 0.10000424835007789
        ),
        food_report_overlap_to_area_ratio=(
            3.710157597271313 if is_buffered else 5.027907881685991
        ),
        difference_in_report_overlap_vs_food_v0_1=(
            -0.0404949381327334 if is_buffered else -0.0528683914510686
        ),
        distance_semantics="SELECTED_CELL_FOOTPRINT_BUFFER_DISTANCE_METERS",
        footprint_semantics="BUFFERED_FOOTPRINT_AREA_SHARE_NOT_FIXED_TOP_10_PERCENT",
        calculation_path="BIGQUERY_GIS_AGGREGATE_ONLY",
        evaluation_kind="POST_LOCK_DESCRIPTIVE_SENSITIVITY",
        outcome_role="VALIDATION_ONLY_NOT_TRAINING",
        evaluated_variant_id="v0_3_equal_group_internal_simulation_r150",
        baseline_variant_id="food_market_only_v0_1",
        specification_git_head="a54ef1dd02c0d6ba692a8ed7a07fd9026686b64a",
        source_csv_sha256="b5f9f5223aa514bc3b02159f974efbb72e5cb75333384dde8a98f281305aa37a",
        observed_from="2026-05-02T23:06:00",
        observed_to="2026-07-08T09:56:00",
        score_semantics="REPORT_OVERLAP_FRACTION_NOT_PROBABILITY_OR_ACCURACY",
        evidence_state="NO_TRUSTED_RESULT",
        use_state="INTERNAL_RESEARCH_ONLY",
        operational_use="PROHIBITED",
        public_release_ready=False,
        literature_doi="10.1071/WR11149",
        literature_interpretation="200m is a literature-anchored upper-bound sensitivity",
        limitation_codes=[
            "DEVELOPMENT_EXPOSED_RETROSPECTIVE",
            "NOT_PROBABILITY_OR_ACCURACY",
        ],
    )


class _RecordingEvaluationRepo:
    def __init__(self) -> None:
        self.call_count = 0

    def get_summary(self) -> V03EvaluationSummaryResponse:
        self.call_count += 1
        return V03EvaluationSummaryResponse(
            rows=[_evaluation_row(0), _evaluation_row(200)]
        )


class _InvalidEvaluationRepo:
    def get_summary(self) -> V03EvaluationSummaryResponse:
        raise ValueError("raw provider detail that must not reach the response")


class V03LabApiTest(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = _RecordingV03Repo()
        self.evaluation_repo = _RecordingEvaluationRepo()
        settings = replace(get_settings(), lab_v03_enabled=True)
        app.dependency_overrides[get_settings] = lambda: settings
        app.dependency_overrides[get_v03_cells_repository] = lambda: self.repo
        app.dependency_overrides[
            get_v03_evaluation_repository
        ] = lambda: self.evaluation_repo
        self.client = TestClient(app)

    def tearDown(self) -> None:
        app.dependency_overrides.clear()

    def test_internal_simulation_endpoint_is_explicitly_labeled(self) -> None:
        response = self.client.get(
            "/api/v1/lab/v0.3/cells",
            params={"bbox": "121.45,24.95,121.67,25.22"},
        )
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(
            body["scenario_id"],
            "v0_3_equal_group_internal_simulation_r150",
        )
        self.assertEqual(
            body["release_state"],
            "SPECIFICATION_LOCKED_INTERNAL_SIMULATION_ONLY",
        )
        self.assertEqual(self.repo.last_call[1], 500)

    def test_limit_is_clamped(self) -> None:
        self.client.get(
            "/api/v1/lab/v0.3/cells",
            params={"bbox": "121.45,24.95,121.67,25.22", "limit": 999999},
        )
        self.assertEqual(self.repo.last_call[1], 1500)

    def test_invalid_bbox_is_rejected_before_repository(self) -> None:
        response = self.client.get(
            "/api/v1/lab/v0.3/cells", params={"bbox": "invalid"}
        )
        self.assertEqual(response.status_code, 422)
        self.assertIsNone(self.repo.last_call)

    def test_evaluation_summary_is_flat_chart_ready_and_fail_closed(self) -> None:
        response = self.client.get("/api/v1/lab/v0.3/evaluation-summary")

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["kind"], "V0_3_EVALUATION_SUMMARY")
        self.assertEqual(body["evidence_state"], "NO_TRUSTED_RESULT")
        self.assertEqual(body["use_state"], "INTERNAL_RESEARCH_ONLY")
        self.assertEqual(body["operational_use"], "PROHIBITED")
        self.assertFalse(body["public_release_ready"])
        self.assertEqual(
            body["score_semantics"],
            "REPORT_OVERLAP_FRACTION_NOT_PROBABILITY_OR_ACCURACY",
        )
        self.assertEqual(
            [row["ecological_tolerance_m"] for row in body["rows"]],
            [0, 200],
        )
        self.assertEqual(body["rows"][1]["v0_3_overlapping_report_count"], 650)
        self.assertEqual(body["rows"][1]["food_overlapping_report_count"], 686)
        self.assertNotIn("calibrated_probability", body["rows"][1])
        self.assertNotIn("accuracy", body["rows"][1])
        self.assertEqual(self.evaluation_repo.call_count, 1)

    def test_evaluation_summary_is_disabled_by_lab_gate(self) -> None:
        app.dependency_overrides[get_settings] = lambda: replace(
            get_settings(), lab_v03_enabled=False
        )

        response = self.client.get("/api/v1/lab/v0.3/evaluation-summary")

        self.assertEqual(response.status_code, 404)
        self.assertEqual(response.json()["code"], "CAPABILITY_NOT_AVAILABLE")
        self.assertEqual(self.evaluation_repo.call_count, 0)

    def test_evaluation_contract_failure_uses_problem_json_without_raw_detail(self) -> None:
        app.dependency_overrides[
            get_v03_evaluation_repository
        ] = lambda: _InvalidEvaluationRepo()

        response = self.client.get("/api/v1/lab/v0.3/evaluation-summary")

        self.assertEqual(response.status_code, 503)
        self.assertEqual(
            response.headers["content-type"], "application/problem+json"
        )
        self.assertEqual(response.json()["code"], "DATA_GATE_FAILED")
        self.assertNotIn("raw provider detail", response.text)


if __name__ == "__main__":
    unittest.main()
