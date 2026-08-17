import unittest
from dataclasses import replace

from fastapi.testclient import TestClient

from services.hotspot_api.config import get_settings
from services.hotspot_api.dependencies import get_v03_cells_repository
from services.hotspot_api.public_app import app
from services.hotspot_api.schemas.lab_v03 import V03LabFeatureCollection


class _RecordingV03Repo:
    def __init__(self) -> None:
        self.last_call = None

    def list_cells(self, bbox, limit, page_token):
        self.last_call = (bbox, limit, page_token)
        return V03LabFeatureCollection(features=[])


class V03LabApiTest(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = _RecordingV03Repo()
        settings = replace(get_settings(), lab_v03_enabled=True)
        app.dependency_overrides[get_settings] = lambda: settings
        app.dependency_overrides[get_v03_cells_repository] = lambda: self.repo
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


if __name__ == "__main__":
    unittest.main()
