import unittest
from pathlib import Path

from services.hotspot_api.repositories.v03_cells_repo import (
    _COLUMNS,
    V03CellsRepository,
)


def _row(cell_id: int, score: float | None) -> dict[str, object]:
    return {
        "cell_id": cell_id,
        "eligible_geojson": (
            '{"type":"Polygon","coordinates":'
            '[[[121.5,25.0],[121.51,25.0],[121.51,25.01],'
            '[121.5,25.01],[121.5,25.0]]]}'
        ),
        "centroid_longitude": 121.505,
        "centroid_latitude": 25.005,
        "food_score": 0.8,
        "sewer_system_type_score": 0.2,
        "sewer_system_type_diagnostic": 0.2,
        "surface_elevation_diagnostic": 0.4,
        "connected_pipe_diameter_diagnostic": 0.5,
        "connected_pipe_depth_diagnostic": 0.6,
        "connected_pipe_age_diagnostic": 0.7,
        "sewer_attribute_index": 0.48,
        "approved_rebuilding_admin_site_r0": 0.1,
        "approved_rebuilding_admin_site_r150": 0.3,
        "approved_rebuilding_admin_site_r300": 0.4,
        "v0_3_simulation_index": score,
        "rank_within_scoreable_support": 0.75 if score is not None else None,
        "preregistered_selected_scenario_area_flag": False,
        "scenario_state": "BLOCKED_INTERNAL_SIMULATION",
        "specification_state": "LOCKED",
        "use_state": "INTERNAL_SIMULATION_ONLY",
        "operational_use": "PROHIBITED",
        "limitation_codes": [
            "NO_TRUSTED_RESULT",
            "ORDINAL_SIMULATION_INDEX_NOT_PROBABILITY",
        ],
        "scenario_id": "v0_3_equal_group_internal_simulation_r150",
        "release_state": "SPECIFICATION_LOCKED_INTERNAL_SIMULATION_ONLY",
        "score_semantics": "ORDINAL_SIMULATION_INDEX_NOT_PROBABILITY",
        "evidence_state": "NO_TRUSTED_RESULT",
        "calibrated_probability": None,
    }


class _FakeGateway:
    def __init__(self) -> None:
        self.calls = []

    def query(self, sql, parameters):
        self.calls.append((sql, parameters))
        return [_row(100, 0.6), _row(101, None)]


class V03CellsRepositoryTest(unittest.TestCase):
    def test_allowlist_columns_exist_in_map_payload_sql(self) -> None:
        root = Path(__file__).resolve().parents[1]
        payload_sql = (
            root / "sql" / "structural" / "18_materialize_map_payload_v0_3.sql"
        ).read_text(encoding="utf-8")
        for column in _COLUMNS:
            self.assertIn(column, payload_sql)

    def test_maps_allowlisted_internal_simulation_rows_and_paginates(self) -> None:
        gateway = _FakeGateway()
        repository = V03CellsRepository(
            gateway,
            "project.subterrat_predictions.map_hotspot_cells_v0_3_internal_simulation",
        )
        result = repository.list_cells((121.4, 24.9, 121.7, 25.3), 1, None)

        self.assertEqual(len(result.features), 1)
        self.assertIsNotNone(result.next_page_token)
        feature = result.features[0]
        self.assertEqual(feature.id, "100")
        self.assertEqual(
            feature.properties.scores.v0_3_equal_group_internal_simulation_r150,
            0.6,
        )
        self.assertIsNone(feature.properties.calibrated_probability)
        self.assertEqual(feature.properties.evidence_state, "NO_TRUSTED_RESULT")

        sql, parameters = gateway.calls[0]
        self.assertNotIn("SELECT *", sql.upper())
        self.assertIn("map_hotspot_cells_v0_3_internal_simulation", sql)
        self.assertIn("@west, @south, @east, @north", sql)
        parameter_values = {parameter.name: parameter.value for parameter in parameters}
        self.assertEqual(parameter_values["west"], 121.4)
        self.assertEqual(parameter_values["south"], 24.9)
        self.assertEqual(parameter_values["east"], 121.7)
        self.assertEqual(parameter_values["north"], 25.3)
        self.assertEqual(parameters[-1].value, 2)


if __name__ == "__main__":
    unittest.main()
