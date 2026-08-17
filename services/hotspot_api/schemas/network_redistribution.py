from __future__ import annotations

from typing import Literal

from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field, field_validator


NetworkScenarioId = Literal[
    "n0_uniform_sewer_link_comparator",
    "n1_metric_weighted_sewer_links",
    "n2_generic_cell_adjacency_sensitivity",
]
CellSupportState = Literal[
    "METRIC_SEWER_SUPPORTED",
    "NO_ELIGIBLE_SEWER_NEIGHBOR",
    "SEWER_ATTRIBUTE_MISSING",
    "GENERIC_ADJACENCY_ONLY",
    "SELF_ONLY",
]


class NetworkBaseMetadata(BaseModel):
    model_config = ConfigDict(extra="forbid")

    schema_version: Literal["0.3.0"] = "0.3.0"
    contract_hash: str = Field(..., pattern=r"^[0-9a-f]{64}$")
    finalized_input_manifest_hash: str = Field(..., pattern=r"^[0-9a-f]{64}$")
    run_id: str = Field(..., pattern=r"^[0-9a-f]{64}$")
    scenario_id: NetworkScenarioId
    use_state: Literal["INTERNAL_SIMULATION_ONLY"] = "INTERNAL_SIMULATION_ONLY"
    evidence_state: Literal["NO_TRUSTED_RESULT"] = "NO_TRUSTED_RESULT"
    operational_use: Literal["PROHIBITED"] = "PROHIBITED"
    global_limitation_codes: list[str] = Field(..., min_length=1)


class NetworkCellsMetadata(NetworkBaseMetadata):
    abstract_iteration: int = Field(..., ge=0, le=8)
    normalization_scope: Literal[
        "LOCKED_RUN_GLOBAL_ALL_SCENARIOS_AND_ITERATIONS"
    ] = "LOCKED_RUN_GLOBAL_ALL_SCENARIOS_AND_ITERATIONS"
    display_scale_max: str = Field(
        ...,
        pattern=r"^(0|[1-9][0-9]*)\.[0-9]{24}$",
    )

    @field_validator("display_scale_max")
    @classmethod
    def require_positive_scale(cls, value: str) -> str:
        if Decimal(value) <= 0:
            raise ValueError("display_scale_max must be strictly positive")
        return value


class NetworkCell(BaseModel):
    model_config = ConfigDict(extra="forbid")

    cell_id: str = Field(..., pattern=r"^(0|-?[1-9][0-9]*)$")
    eligible_geojson: str
    relative_synthetic_network_state: str = Field(
        ...,
        pattern=r"^(0\.[0-9]{12}|1\.000000000000)$",
    )
    sewer_attribute_available: bool
    eligible_sewer_neighbor_count: int = Field(..., ge=0)
    eligible_generic_neighbor_count: int = Field(..., ge=0)
    self_only_transition_row: bool
    cell_support_state: CellSupportState
    cell_limitation_codes: list[str] = Field(..., min_length=2)


class NetworkCellsResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    kind: Literal["NETWORK_REDISTRIBUTION_CELLS"] = (
        "NETWORK_REDISTRIBUTION_CELLS"
    )
    metadata: NetworkCellsMetadata
    cells: list[NetworkCell] = Field(..., min_length=3420, max_length=3420)


class NetworkCoordinate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    longitude: str = Field(..., pattern=r"^-?(0|[1-9][0-9]*)\.[0-9]{7}$")
    latitude: str = Field(..., pattern=r"^-?(0|[1-9][0-9]*)\.[0-9]{7}$")

    @field_validator("longitude", "latitude")
    @classmethod
    def reject_negative_zero(cls, value: str) -> str:
        if value.startswith("-") and Decimal(value) == 0:
            raise ValueError("negative zero is not canonical")
        return value


class NetworkLink(BaseModel):
    model_config = ConfigDict(extra="forbid")

    from_cell_id: str = Field(..., pattern=r"^(0|-?[1-9][0-9]*)$")
    to_cell_id: str = Field(..., pattern=r"^(0|-?[1-9][0-9]*)$")
    link_class: Literal["SYNTHETIC_SEWER_LINK", "GENERIC_CELL_ADJACENCY"]
    active_in_scenario: Literal[True] = True
    metric_eligible: bool | None
    schematic_from_centroid: NetworkCoordinate
    schematic_to_centroid: NetworkCoordinate
    link_limitation_codes: list[str] = Field(..., min_length=2, max_length=2)


class NetworkLinksResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    kind: Literal["NETWORK_REDISTRIBUTION_LINKS"] = (
        "NETWORK_REDISTRIBUTION_LINKS"
    )
    metadata: NetworkBaseMetadata
    links: list[NetworkLink]
