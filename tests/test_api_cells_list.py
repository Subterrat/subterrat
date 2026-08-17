import unittest

from fastapi.testclient import TestClient

from services.hotspot_api.dependencies import get_cells_repository, get_releases_repository
from services.hotspot_api.public_app import app
from services.hotspot_api.schemas.cells import CellFeatureCollection

_RELEASE_ID = "t0-layerwise-development-20260817-v2"


class _FakeReleasesRepo:
    def current_release_id(self):
        return _RELEASE_ID

    def is_readable(self, release_id):
        return release_id == _RELEASE_ID


class _RecordingCellsRepo:
    def __init__(self) -> None:
        self.last_limit = None

    def list_cells(self, release_id, bbox, limit, page_token):
        self.last_limit = limit
        return CellFeatureCollection(
            release_id=release_id, prediction_run_id=release_id, features=[]
        )

    def get_cell(self, release_id, cell_id):
        return None


class CellsListTest(unittest.TestCase):
    def setUp(self) -> None:
        self.fake_cells_repo = _RecordingCellsRepo()
        app.dependency_overrides[get_releases_repository] = _FakeReleasesRepo
        app.dependency_overrides[get_cells_repository] = lambda: self.fake_cells_repo
        self.client = TestClient(app)

    def tearDown(self) -> None:
        app.dependency_overrides.clear()

    def test_valid_bbox_returns_feature_collection_shape(self) -> None:
        response = self.client.get(
            f"/api/v1/releases/{_RELEASE_ID}/cells",
            params={"bbox": "121.48,25.01,121.58,25.10"},
        )
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["type"], "FeatureCollection")
        self.assertEqual(body["release_id"], _RELEASE_ID)
        self.assertIsNone(body["target_window"])
        self.assertEqual(body["truncated"], False)

    def test_default_limit_is_500(self) -> None:
        self.client.get(
            f"/api/v1/releases/{_RELEASE_ID}/cells",
            params={"bbox": "121.48,25.01,121.58,25.10"},
        )
        self.assertEqual(self.fake_cells_repo.last_limit, 500)

    def test_limit_is_clamped_to_max_features_per_request(self) -> None:
        self.client.get(
            f"/api/v1/releases/{_RELEASE_ID}/cells",
            params={"bbox": "121.48,25.01,121.58,25.10", "limit": 999999},
        )
        self.assertEqual(self.fake_cells_repo.last_limit, 1500)

    def test_cell_not_found(self) -> None:
        response = self.client.get(f"/api/v1/releases/{_RELEASE_ID}/cells/123456")
        self.assertEqual(response.status_code, 404)
        self.assertEqual(response.json()["code"], "CELL_NOT_FOUND")


if __name__ == "__main__":
    unittest.main()
