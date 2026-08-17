import unittest

from fastapi.testclient import TestClient

from services.hotspot_api.dependencies import get_releases_repository
from services.hotspot_api.public_app import app

_RELEASE_ID = "t0-layerwise-development-20260817-v2"


class _FakeReleasesRepo:
    def current_release_id(self):
        return _RELEASE_ID

    def is_readable(self, release_id):
        return release_id == _RELEASE_ID


class ReleasesTest(unittest.TestCase):
    """This service resolves a release by actually querying BigQuery for
    the configured RELEASE_ID (GitHub issue #4) — there is no
    always-unpublished stub anymore. These tests fake that BigQuery check
    directly rather than hitting real BigQuery.
    """

    def setUp(self) -> None:
        app.dependency_overrides[get_releases_repository] = _FakeReleasesRepo
        self.client = TestClient(app)

    def tearDown(self) -> None:
        app.dependency_overrides.clear()

    def test_current_release_is_found(self) -> None:
        response = self.client.get("/api/v1/releases/current")
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["release_id"], _RELEASE_ID)
        self.assertTrue(body["href"].endswith("/cells"))

    def test_map_bootstrap_resolves_configured_release(self) -> None:
        response = self.client.get("/api/v1/map/bootstrap")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["current_release_id"], _RELEASE_ID)

    def test_unknown_release_id_is_not_found_for_cells(self) -> None:
        response = self.client.get(
            "/api/v1/releases/some-other-release/cells",
            params={"bbox": "121.48,25.01,121.58,25.10"},
        )
        self.assertEqual(response.status_code, 404)
        self.assertEqual(response.json()["code"], "RELEASE_NOT_FOUND")

    def test_unknown_release_id_is_not_found_for_cell_detail(self) -> None:
        response = self.client.get("/api/v1/releases/some-other-release/cells/123456")
        self.assertEqual(response.status_code, 404)
        self.assertEqual(response.json()["code"], "RELEASE_NOT_FOUND")


if __name__ == "__main__":
    unittest.main()
