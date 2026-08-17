import unittest

from fastapi.testclient import TestClient

from services.hotspot_api.dependencies import get_cells_repository, get_releases_repository
from services.hotspot_api.public_app import app

_RELEASE_ID = "t0-layerwise-development-20260817-v2"


class _FakeReleasesRepo:
    def current_release_id(self):
        return _RELEASE_ID

    def is_readable(self, release_id):
        return release_id == _RELEASE_ID


class _UncalledCellsRepo:
    def list_cells(self, *args, **kwargs):
        raise AssertionError("BigQuery must not be queried when bbox validation fails")

    def get_cell(self, *args, **kwargs):
        raise AssertionError("BigQuery must not be queried when cell_id validation fails")


class CellsValidationTest(unittest.TestCase):
    def setUp(self) -> None:
        app.dependency_overrides[get_releases_repository] = _FakeReleasesRepo
        app.dependency_overrides[get_cells_repository] = _UncalledCellsRepo
        self.client = TestClient(app)

    def tearDown(self) -> None:
        app.dependency_overrides.clear()

    def test_malformed_bbox_is_rejected_before_bigquery(self) -> None:
        response = self.client.get(
            f"/api/v1/releases/{_RELEASE_ID}/cells", params={"bbox": "not-a-bbox"}
        )
        self.assertEqual(response.status_code, 422)
        self.assertEqual(response.json()["code"], "INVALID_BBOX")

    def test_inverted_bbox_is_rejected(self) -> None:
        response = self.client.get(
            f"/api/v1/releases/{_RELEASE_ID}/cells",
            params={"bbox": "121.58,25.10,121.48,25.01"},
        )
        self.assertEqual(response.status_code, 422)
        self.assertEqual(response.json()["code"], "INVALID_BBOX")

    def test_non_numeric_cell_id_is_not_found_before_bigquery(self) -> None:
        response = self.client.get(f"/api/v1/releases/{_RELEASE_ID}/cells/not-a-cell")
        self.assertEqual(response.status_code, 404)
        self.assertEqual(response.json()["code"], "CELL_NOT_FOUND")


if __name__ == "__main__":
    unittest.main()
