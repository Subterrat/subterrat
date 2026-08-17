from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from services.hotspot_api.schemas.common import GeoJsonMultiPolygon, GeoJsonPolygon


class V03Scores(BaseModel):
    model_config = ConfigDict(extra="forbid")

    food_market_v0_1: float | None = Field(None, ge=0, le=1)
    sewer_system_type_v0_1: float | None = Field(None, ge=0, le=1)
    sewer_system_type_v0_2: float | None = Field(None, ge=0, le=1)
    surface_elevation_v0_2: float | None = Field(None, ge=0, le=1)
    connected_pipe_diameter_v0_2: float | None = Field(None, ge=0, le=1)
    connected_pipe_depth_v0_2: float | None = Field(None, ge=0, le=1)
    connected_pipe_age_v0_2: float | None = Field(None, ge=0, le=1)
    sewer_attribute_index_v0_2: float | None = Field(None, ge=0, le=1)
    approved_rebuilding_admin_site_buffer_0m: float | None = Field(None, ge=0, le=1)
    approved_rebuilding_admin_site_buffer_150m: float | None = Field(
        None, ge=0, le=1
    )
    approved_rebuilding_admin_site_buffer_300m: float | None = Field(
        None, ge=0, le=1
    )
    v0_3_equal_group_internal_simulation_r150: float | None = Field(
        None, ge=0, le=1
    )


class V03LabCellProperties(BaseModel):
    model_config = ConfigDict(extra="forbid")

    cell_id: str = Field(..., pattern=r"^[0-9]+$")
    centroid_longitude: float = Field(..., ge=-180, le=180)
    centroid_latitude: float = Field(..., ge=-90, le=90)
    scenario_id: Literal["v0_3_equal_group_internal_simulation_r150"]
    release_state: Literal["SPECIFICATION_LOCKED_INTERNAL_SIMULATION_ONLY"]
    score_semantics: Literal["ORDINAL_SIMULATION_INDEX_NOT_PROBABILITY"]
    specification_state: Literal["LOCKED"]
    use_state: Literal["INTERNAL_SIMULATION_ONLY"]
    evidence_state: Literal["NO_TRUSTED_RESULT"]
    operational_use: Literal["PROHIBITED"]
    calibrated_probability: None = None
    scenario_state: str
    rank_within_scoreable_support: float | None = Field(None, ge=0, le=1)
    preregistered_selected_scenario_area: bool
    scores: V03Scores
    limitation_codes: list[str] = Field(..., min_length=1)


class V03LabCellFeature(BaseModel):
    model_config = ConfigDict(extra="forbid")

    type: Literal["Feature"] = "Feature"
    id: str = Field(..., pattern=r"^[0-9]+$")
    geometry: GeoJsonPolygon | GeoJsonMultiPolygon
    properties: V03LabCellProperties


class V03LabFeatureCollection(BaseModel):
    model_config = ConfigDict(extra="forbid")

    type: Literal["FeatureCollection"] = "FeatureCollection"
    scenario_id: Literal["v0_3_equal_group_internal_simulation_r150"] = (
        "v0_3_equal_group_internal_simulation_r150"
    )
    release_state: Literal["SPECIFICATION_LOCKED_INTERNAL_SIMULATION_ONLY"] = (
        "SPECIFICATION_LOCKED_INTERNAL_SIMULATION_ONLY"
    )
    features: list[V03LabCellFeature] = Field(default_factory=list, max_length=1500)
    next_page_token: str | None = None
    truncated: Literal[False] = False
