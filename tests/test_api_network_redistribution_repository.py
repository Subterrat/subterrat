import unittest
from decimal import Decimal

from services.hotspot_api.repositories.network_redistribution_repo import (
    NetworkRedistributionRepository,
)


_HASH = "1" * 64
_POLYGON = (
    '{"type":"Polygon","coordinates":'
    '[[[121.5,25.0],[121.51,25.0],[121.51,25.01],'
    '[121.5,25.01],[121.5,25.0]]]}'
)


def _cell_row(cell_id: int) -> dict[str, object]:
    return {
        "contract_hash": _HASH,
        "finalized_input_manifest_hash": _HASH,
        "run_id": _HASH,
        "cell_id": cell_id,
        "eligible_geojson_canonical_text": _POLYGON,
        "relative_synthetic_network_state": Decimal("0.125"),
        "display_scale_max": Decimal("0.25"),
        "sewer_attribute_available": True,
        "eligible_sewer_neighbor_count": 2,
        "eligible_generic_neighbor_count": 4,
        "self_only_transition_row": False,
        "cell_support_state": "METRIC_SEWER_SUPPORTED",
        "cell_limitation_codes": [
            "CELL_GRAPH_IS_NOT_TRUE_SEWER_TOPOLOGY",
            "V0_2_SEWER_METRIC_GATES_INCOMPLETE",
        ],
    }


class _FakeGateway:
    def __init__(self, rows) -> None:
        self.rows = rows
        self.calls = []

    def query(self, sql, parameters):
        self.calls.append((sql, parameters))
        return self.rows


def _repository(gateway):
    return NetworkRedistributionRepository(
        gateway,
        "project.subterrat_simulations.map_cells",
        "project.subterrat_simulations.states",
        "project.subterrat_simulations.links",
        "project.subterrat_simulations.receipt",
    )


class NetworkRedistributionRepositoryTest(unittest.TestCase):
    def test_cells_use_fixed_decimal_strings_and_exact_canonical_order(self) -> None:
        gateway = _FakeGateway([_cell_row(cell_id) for cell_id in range(3420)])
        result = _repository(gateway).list_cells(
            "n1_metric_weighted_sewer_links", 2
        )

        self.assertEqual(len(result.cells), 3420)
        self.assertEqual(
            result.cells[0].relative_synthetic_network_state,
            "0.125000000000",
        )
        self.assertEqual(
            result.metadata.display_scale_max,
            "0.250000000000000000000000",
        )
        self.assertEqual(result.metadata.evidence_state, "NO_TRUSTED_RESULT")
        sql, parameters = gateway.calls[0]
        self.assertNotIn("SELECT *", sql.upper())
        self.assertIn("ORDER BY map.cell_id", sql)
        self.assertEqual(parameters[0].value, "n1_metric_weighted_sewer_links")
        self.assertEqual(parameters[1].value, 2)

    def test_cells_fail_closed_on_incomplete_artifact(self) -> None:
        with self.assertRaisesRegex(ValueError, "not 3420 rows"):
            _repository(_FakeGateway([_cell_row(1)])).list_cells(
                "n1_metric_weighted_sewer_links", 0
            )

    def test_n2_links_preserve_class_orientation_and_exact_codes(self) -> None:
        rows = [
            {
                "contract_hash": _HASH,
                "finalized_input_manifest_hash": _HASH,
                "run_id": _HASH,
                "link_class": "GENERIC_CELL_ADJACENCY",
                "from_cell_id": -2,
                "to_cell_id": 3,
                "metric_eligible": None,
                "from_longitude": Decimal("121.5"),
                "from_latitude": Decimal("25.0"),
                "to_longitude": Decimal("121.6"),
                "to_latitude": Decimal("25.1"),
                "link_limitation_codes": [
                    "GENERIC_ADJACENCY_BARRIERS_NOT_MODELED",
                    "SCHEMATIC_CENTROID_LINK_NOT_PIPE_ALIGNMENT",
                ],
            },
            {
                "contract_hash": _HASH,
                "finalized_input_manifest_hash": _HASH,
                "run_id": _HASH,
                "link_class": "SYNTHETIC_SEWER_LINK",
                "from_cell_id": 1,
                "to_cell_id": 4,
                "metric_eligible": True,
                "from_longitude": Decimal("121.5"),
                "from_latitude": Decimal("25.0"),
                "to_longitude": Decimal("121.6"),
                "to_latitude": Decimal("25.1"),
                "link_limitation_codes": [
                    "SCHEMATIC_CENTROID_LINK_NOT_PIPE_ALIGNMENT",
                    "V0_2_SEWER_METRIC_GATES_INCOMPLETE",
                ],
            },
        ]
        result = _repository(_FakeGateway(rows)).list_links(
            "n2_generic_cell_adjacency_sensitivity"
        )
        self.assertEqual(len(result.links), 2)
        self.assertEqual(result.links[0].from_cell_id, "-2")
        self.assertIsNone(result.links[0].metric_eligible)
        self.assertEqual(
            result.links[1].schematic_from_centroid.longitude,
            "121.5000000",
        )
        self.assertIn(
            "GENERIC_ADJACENCY_BARRIERS_NOT_MODELED",
            result.metadata.global_limitation_codes,
        )

    def test_link_serializer_rejects_noncanonical_orientation(self) -> None:
        row = {
            "contract_hash": _HASH,
            "finalized_input_manifest_hash": _HASH,
            "run_id": _HASH,
            "link_class": "SYNTHETIC_SEWER_LINK",
            "from_cell_id": 4,
            "to_cell_id": 1,
            "metric_eligible": True,
            "from_longitude": Decimal("121.5"),
            "from_latitude": Decimal("25.0"),
            "to_longitude": Decimal("121.6"),
            "to_latitude": Decimal("25.1"),
            "link_limitation_codes": [
                "SCHEMATIC_CENTROID_LINK_NOT_PIPE_ALIGNMENT",
                "V0_2_SEWER_METRIC_GATES_INCOMPLETE",
            ],
        }
        with self.assertRaisesRegex(ValueError, "canonical orientation"):
            _repository(_FakeGateway([row])).list_links(
                "n1_metric_weighted_sewer_links"
            )


if __name__ == "__main__":
    unittest.main()
