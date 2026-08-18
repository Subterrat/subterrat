import unittest
from dataclasses import replace

from fastapi.testclient import TestClient

from services.hotspot_api.config import get_settings
from services.hotspot_api.dependencies import (
    get_network_redistribution_repository,
)
from services.hotspot_api.public_app import app
from services.hotspot_api.schemas.network_redistribution import (
    NetworkBaseMetadata,
    NetworkCell,
    NetworkCellsMetadata,
    NetworkCellsResponse,
    NetworkLinksResponse,
)


_HASH = "0" * 64


def _cell(cell_id: int) -> NetworkCell:
    return NetworkCell(
        cell_id=str(cell_id),
        eligible_geojson='{"type":"Polygon","coordinates":[]}',
        relative_synthetic_network_state="0.000000000000",
        sewer_attribute_available=True,
        eligible_sewer_neighbor_count=1,
        eligible_generic_neighbor_count=1,
        self_only_transition_row=False,
        cell_support_state="METRIC_SEWER_SUPPORTED",
        cell_limitation_codes=[
            "CELL_GRAPH_IS_NOT_TRUE_SEWER_TOPOLOGY",
            "V0_2_SEWER_METRIC_GATES_INCOMPLETE",
        ],
    )


class _RecordingNetworkRepo:
    def __init__(self) -> None:
        self.last_cells_call = None
        self.last_links_call = None

    def list_cells(self, scenario_id, abstract_iteration):
        self.last_cells_call = (scenario_id, abstract_iteration)
        return NetworkCellsResponse(
            metadata=NetworkCellsMetadata(
                contract_hash=_HASH,
                finalized_input_manifest_hash=_HASH,
                run_id=_HASH,
                scenario_id=scenario_id,
                abstract_iteration=abstract_iteration,
                display_scale_max="1.000000000000000000000000",
                global_limitation_codes=["NO_TRUSTED_RESULT"],
            ),
            cells=[_cell(cell_id) for cell_id in range(3420)],
        )

    def list_links(self, scenario_id):
        self.last_links_call = scenario_id
        return NetworkLinksResponse(
            metadata=NetworkBaseMetadata(
                contract_hash=_HASH,
                finalized_input_manifest_hash=_HASH,
                run_id=_HASH,
                scenario_id=scenario_id,
                global_limitation_codes=["NO_TRUSTED_RESULT"],
            ),
            links=[],
        )


class NetworkRedistributionApiTest(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = _RecordingNetworkRepo()
        settings = replace(get_settings(), lab_v03_enabled=True)
        app.dependency_overrides[get_settings] = lambda: settings
        app.dependency_overrides[
            get_network_redistribution_repository
        ] = lambda: self.repo
        self.client = TestClient(app)

    def tearDown(self) -> None:
        app.dependency_overrides.clear()

    def test_cells_route_accepts_only_locked_scenario_and_abstract_iteration(self) -> None:
        response = self.client.get(
            "/api/v1/lab/v0.3/network-redistribution/cells",
            params={
                "scenario_id": "n1_metric_weighted_sewer_links",
                "abstract_iteration": 4,
            },
        )
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["kind"], "NETWORK_REDISTRIBUTION_CELLS")
        self.assertEqual(body["metadata"]["abstract_iteration"], 4)
        self.assertEqual(body["metadata"]["evidence_state"], "NO_TRUSTED_RESULT")
        self.assertEqual(body["metadata"]["operational_use"], "PROHIBITED")
        self.assertEqual(len(body["cells"]), 3420)
        self.assertEqual(
            self.repo.last_cells_call,
            ("n1_metric_weighted_sewer_links", 4),
        )

    def test_links_route_is_scenario_scoped(self) -> None:
        response = self.client.get(
            "/api/v1/lab/v0.3/network-redistribution/links",
            params={"scenario_id": "n2_generic_cell_adjacency_sensitivity"},
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["kind"], "NETWORK_REDISTRIBUTION_LINKS")
        self.assertEqual(
            self.repo.last_links_call,
            "n2_generic_cell_adjacency_sensitivity",
        )

    def test_arbitrary_scenario_or_iteration_is_rejected(self) -> None:
        bad_scenario = self.client.get(
            "/api/v1/lab/v0.3/network-redistribution/cells",
            params={"scenario_id": "custom", "abstract_iteration": 0},
        )
        bad_iteration = self.client.get(
            "/api/v1/lab/v0.3/network-redistribution/cells",
            params={
                "scenario_id": "n1_metric_weighted_sewer_links",
                "abstract_iteration": 9,
            },
        )
        self.assertEqual(bad_scenario.status_code, 422)
        self.assertEqual(bad_iteration.status_code, 422)

    def test_route_is_disabled_by_default_gate(self) -> None:
        app.dependency_overrides[get_settings] = lambda: replace(
            get_settings(), lab_v03_enabled=False
        )
        response = self.client.get(
            "/api/v1/lab/v0.3/network-redistribution/links",
            params={"scenario_id": "n1_metric_weighted_sewer_links"},
        )
        self.assertEqual(response.status_code, 404)


if __name__ == "__main__":
    unittest.main()
