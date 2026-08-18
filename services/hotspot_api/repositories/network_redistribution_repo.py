from __future__ import annotations

import json
from decimal import Decimal
from typing import Any

from google.cloud import bigquery

from services.hotspot_api.bigquery_gateway import BigQueryGateway
from services.hotspot_api.schemas.network_redistribution import (
    NetworkBaseMetadata,
    NetworkCell,
    NetworkCellsMetadata,
    NetworkCellsResponse,
    NetworkCoordinate,
    NetworkLink,
    NetworkLinksResponse,
    NetworkScenarioId,
)


_BASE_GLOBAL_CODES = (
    "CELL_GRAPH_IS_NOT_TRUE_SEWER_TOPOLOGY",
    "CELL_LEVEL_MIXING_CAN_CONNECT_DISCONNECTED_INTERNAL_SUBNETWORKS",
    "ITERATION_8_NOT_CONVERGENCE_OR_FINAL_STATE",
    "NO_FIELD_GROUND_TRUTH",
    "NO_TAIPEI_MOVEMENT_OR_TEMPORAL_CALIBRATION",
    "NO_TRUSTED_RESULT",
    "PIPE_FLOW_AND_RAT_MOVEMENT_DIRECTION_UNVERIFIED",
    "RAW_NODE_IDS_HAVE_SPATIAL_CONFLICTS",
    "URBAN_RENEWAL_NOT_USED_NO_RELIABLE_CONSTRUCTION_TIMELINE",
    "V0_2_SEWER_METRIC_GATES_INCOMPLETE",
)
_GENERIC_GLOBAL_CODE = "GENERIC_ADJACENCY_BARRIERS_NOT_MODELED"
_SEWER_LINK_CODES = (
    "SCHEMATIC_CENTROID_LINK_NOT_PIPE_ALIGNMENT",
    "V0_2_SEWER_METRIC_GATES_INCOMPLETE",
)
_GENERIC_LINK_CODES = (
    "GENERIC_ADJACENCY_BARRIERS_NOT_MODELED",
    "SCHEMATIC_CENTROID_LINK_NOT_PIPE_ALIGNMENT",
)


def _global_codes(scenario_id: str) -> list[str]:
    codes = list(_BASE_GLOBAL_CODES)
    if scenario_id == "n2_generic_cell_adjacency_sensitivity":
        codes.append(_GENERIC_GLOBAL_CODE)
    return sorted(codes)


def _fixed_decimal(value: Any, scale: int) -> str:
    decimal = Decimal(value)
    if decimal == 0:
        decimal = abs(decimal)
    return f"{decimal:.{scale}f}"


def _cell_codes(row: dict[str, Any]) -> list[str]:
    codes = {
        "CELL_GRAPH_IS_NOT_TRUE_SEWER_TOPOLOGY",
        "V0_2_SEWER_METRIC_GATES_INCOMPLETE",
    }
    if not row["sewer_attribute_available"]:
        codes.add("SEWER_ATTRIBUTE_MISSING")
    if int(row["eligible_sewer_neighbor_count"]) == 0:
        codes.add("NO_ELIGIBLE_SEWER_NEIGHBOR")
    if row["cell_support_state"] == "GENERIC_ADJACENCY_ONLY":
        codes.add("GENERIC_ADJACENCY_ONLY_SUPPORT")
    if row["self_only_transition_row"]:
        codes.add("SELF_ONLY_TRANSITION_ROW")
    return sorted(codes)


def _base_metadata(row: dict[str, Any], scenario_id: str) -> NetworkBaseMetadata:
    return NetworkBaseMetadata(
        contract_hash=row["contract_hash"],
        finalized_input_manifest_hash=row["finalized_input_manifest_hash"],
        run_id=row["run_id"],
        scenario_id=scenario_id,
        global_limitation_codes=_global_codes(scenario_id),
    )


class NetworkRedistributionRepository:
    def __init__(
        self,
        gateway: BigQueryGateway,
        map_table_ref: str,
        state_table_ref: str,
        links_table_ref: str,
        receipt_table_ref: str,
    ) -> None:
        self._gateway = gateway
        self._map_table_ref = map_table_ref
        self._state_table_ref = state_table_ref
        self._links_table_ref = links_table_ref
        self._receipt_table_ref = receipt_table_ref

    def list_cells(
        self,
        scenario_id: NetworkScenarioId,
        abstract_iteration: int,
    ) -> NetworkCellsResponse:
        sql = f"""
        WITH receipt AS (
          SELECT run_id, contract_hash, finalized_input_manifest_hash
          FROM `{self._receipt_table_ref}`
          WHERE use_state = 'INTERNAL_SIMULATION_ONLY'
            AND evidence_state = 'NO_TRUSTED_RESULT'
            AND operational_use = 'PROHIBITED'
            AND NOT public_release_ready
            AND NOT operational_use_ready
        )
        SELECT
          receipt.contract_hash,
          receipt.finalized_input_manifest_hash,
          receipt.run_id,
          map.cell_id,
          map.eligible_geojson_canonical_text,
          state.relative_synthetic_network_state,
          state.display_scale_max,
          state.sewer_attribute_available,
          state.eligible_sewer_neighbor_count,
          state.eligible_generic_neighbor_count,
          state.self_only_transition_row,
          state.cell_support_state,
          state.cell_limitation_codes
        FROM receipt
        JOIN `{self._map_table_ref}` AS map USING (run_id)
        JOIN `{self._state_table_ref}` AS state
          USING (run_id, scenario_id, abstract_iteration, cell_id)
        WHERE map.scenario_id = @scenario_id
          AND map.abstract_iteration = @abstract_iteration
        ORDER BY map.cell_id
        """
        rows = self._gateway.query(
            sql,
            [
                bigquery.ScalarQueryParameter(
                    "scenario_id", "STRING", scenario_id
                ),
                bigquery.ScalarQueryParameter(
                    "abstract_iteration", "INT64", abstract_iteration
                ),
            ],
        )
        if len(rows) != 3420:
            raise ValueError("network redistribution cell artifact is not 3420 rows")
        first = rows[0]
        display_scale_max = _fixed_decimal(first["display_scale_max"], 24)
        cells: list[NetworkCell] = []
        previous_cell_id: int | None = None
        for row in rows:
            cell_id_int = int(row["cell_id"])
            if previous_cell_id is not None and cell_id_int <= previous_cell_id:
                raise ValueError("network cells are not in canonical signed order")
            previous_cell_id = cell_id_int
            if _fixed_decimal(row["display_scale_max"], 24) != display_scale_max:
                raise ValueError("network cells do not share one locked-run scale")
            expected_codes = _cell_codes(row)
            if list(row.get("cell_limitation_codes") or []) != expected_codes:
                raise ValueError("cell limitation codes violate the wire contract")
            geometry = json.loads(row["eligible_geojson_canonical_text"])
            if geometry.get("type") not in {"Polygon", "MultiPolygon"}:
                raise ValueError("eligible geometry is not polygonal GeoJSON")
            cells.append(
                NetworkCell(
                    cell_id=str(row["cell_id"]),
                    eligible_geojson=row["eligible_geojson_canonical_text"],
                    relative_synthetic_network_state=_fixed_decimal(
                        row["relative_synthetic_network_state"], 12
                    ),
                    sewer_attribute_available=bool(
                        row["sewer_attribute_available"]
                    ),
                    eligible_sewer_neighbor_count=int(
                        row["eligible_sewer_neighbor_count"]
                    ),
                    eligible_generic_neighbor_count=int(
                        row["eligible_generic_neighbor_count"]
                    ),
                    self_only_transition_row=bool(
                        row["self_only_transition_row"]
                    ),
                    cell_support_state=row["cell_support_state"],
                    cell_limitation_codes=expected_codes,
                )
            )
        return NetworkCellsResponse(
            metadata=NetworkCellsMetadata(
                **_base_metadata(first, scenario_id).model_dump(),
                abstract_iteration=abstract_iteration,
                display_scale_max=display_scale_max,
            ),
            cells=cells,
        )

    def list_links(
        self,
        scenario_id: NetworkScenarioId,
    ) -> NetworkLinksResponse:
        sql = f"""
        WITH receipt AS (
          SELECT run_id, contract_hash, finalized_input_manifest_hash
          FROM `{self._receipt_table_ref}`
          WHERE use_state = 'INTERNAL_SIMULATION_ONLY'
            AND evidence_state = 'NO_TRUSTED_RESULT'
            AND operational_use = 'PROHIBITED'
            AND NOT public_release_ready
            AND NOT operational_use_ready
        )
        SELECT
          receipt.contract_hash,
          receipt.finalized_input_manifest_hash,
          receipt.run_id,
          link.link_class,
          link.from_cell_id,
          link.to_cell_id,
          link.metric_eligible,
          link.from_longitude,
          link.from_latitude,
          link.to_longitude,
          link.to_latitude,
          link.link_limitation_codes
        FROM receipt
        JOIN `{self._links_table_ref}` AS link USING (run_id)
        WHERE link.scenario_id = @scenario_id
        ORDER BY link.link_class, link.from_cell_id, link.to_cell_id
        """
        rows = self._gateway.query(
            sql,
            [bigquery.ScalarQueryParameter("scenario_id", "STRING", scenario_id)],
        )
        if not rows:
            raise ValueError("network redistribution link artifact is empty")
        links: list[NetworkLink] = []
        previous_key: tuple[str, int, int] | None = None
        for row in rows:
            from_cell_id = int(row["from_cell_id"])
            to_cell_id = int(row["to_cell_id"])
            key = (row["link_class"], from_cell_id, to_cell_id)
            if from_cell_id >= to_cell_id or (
                previous_key is not None and key <= previous_key
            ):
                raise ValueError("schematic links violate canonical orientation")
            previous_key = key
            if row["link_class"] == "SYNTHETIC_SEWER_LINK":
                expected_codes = list(_SEWER_LINK_CODES)
                if row["metric_eligible"] is not True:
                    raise ValueError("returned sewer link is not metric eligible")
                metric_eligible: bool | None = True
            else:
                expected_codes = list(_GENERIC_LINK_CODES)
                if scenario_id != "n2_generic_cell_adjacency_sensitivity":
                    raise ValueError("generic link returned outside n2 sensitivity")
                if row["metric_eligible"] is not None:
                    raise ValueError("generic link metric eligibility must be null")
                metric_eligible = None
            if list(row.get("link_limitation_codes") or []) != expected_codes:
                raise ValueError("link limitation codes violate the wire contract")
            links.append(
                NetworkLink(
                    from_cell_id=str(row["from_cell_id"]),
                    to_cell_id=str(row["to_cell_id"]),
                    link_class=row["link_class"],
                    metric_eligible=metric_eligible,
                    schematic_from_centroid=NetworkCoordinate(
                        longitude=_fixed_decimal(row["from_longitude"], 7),
                        latitude=_fixed_decimal(row["from_latitude"], 7),
                    ),
                    schematic_to_centroid=NetworkCoordinate(
                        longitude=_fixed_decimal(row["to_longitude"], 7),
                        latitude=_fixed_decimal(row["to_latitude"], 7),
                    ),
                    link_limitation_codes=expected_codes,
                )
            )
        return NetworkLinksResponse(
            metadata=_base_metadata(rows[0], scenario_id),
            links=links,
        )
