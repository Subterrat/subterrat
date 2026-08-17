import unittest

from fastapi.testclient import TestClient

from services.hotspot_api.public_app import app


class ModelCapabilitiesTest(unittest.TestCase):
    def setUp(self) -> None:
        self.client = TestClient(app)

    def test_capabilities_match_contract_matrix(self) -> None:
        response = self.client.get("/api/v1/model-capabilities")
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["contract_version"], "0.1.0")
        self.assertEqual(body["evidence_status"], "NO_TRUSTED_RESULT")
        capabilities = body["capabilities"]
        self.assertEqual(capabilities["daily_time_series_forecast"], "NOT_SUPPORTED")
        self.assertEqual(capabilities["scenario_simulation"], "NOT_SUPPORTED")
        self.assertEqual(capabilities["calibrated_probability"], "NOT_SUPPORTED")
        self.assertEqual(capabilities["live_coordinate_inference"], "NOT_SUPPORTED")
        self.assertEqual(capabilities["spatial_ranking"], "PLANNED")


if __name__ == "__main__":
    unittest.main()
