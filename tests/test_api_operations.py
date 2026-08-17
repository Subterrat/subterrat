import unittest

from fastapi.testclient import TestClient

from services.hotspot_api.dependencies import get_releases_repository
from services.hotspot_api.public_app import app


class _FakeReleasesRepo:
    def __init__(self, readable: bool) -> None:
        self._readable = readable

    def current_release_id(self):
        return "t0-layerwise-development-20260817-v2"

    def is_readable(self, release_id):
        return self._readable and release_id == self.current_release_id()


class OperationsTest(unittest.TestCase):
    def tearDown(self) -> None:
        app.dependency_overrides.clear()

    def test_healthz_is_always_alive(self) -> None:
        client = TestClient(app)
        response = client.get("/healthz")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(), {"status": "alive", "proof_scope": "process_liveness_only"}
        )

    def test_readyz_is_200_when_serving_table_is_readable(self) -> None:
        app.dependency_overrides[get_releases_repository] = lambda: _FakeReleasesRepo(True)
        client = TestClient(app)
        response = client.get("/readyz")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json()["current_release_id"], "t0-layerwise-development-20260817-v2"
        )

    def test_readyz_is_503_when_serving_table_is_not_readable(self) -> None:
        app.dependency_overrides[get_releases_repository] = lambda: _FakeReleasesRepo(False)
        client = TestClient(app)
        response = client.get("/readyz")
        self.assertEqual(response.status_code, 503)
        self.assertEqual(response.headers["content-type"], "application/problem+json")
        self.assertEqual(response.json()["code"], "NO_PUBLISHED_RELEASE")


if __name__ == "__main__":
    unittest.main()
