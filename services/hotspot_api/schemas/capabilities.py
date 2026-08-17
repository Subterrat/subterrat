from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

CapabilityState = Literal["PLANNED", "AVAILABLE", "CONDITIONAL", "NOT_SUPPORTED"]


class Capabilities(BaseModel):
    model_config = ConfigDict(extra="forbid")

    spatial_ranking: CapabilityState
    forecast_window: CapabilityState
    forecast_vintage_history: CapabilityState
    aggregated_released_outcome: CapabilityState
    daily_time_series_forecast: Literal["NOT_SUPPORTED"] = "NOT_SUPPORTED"
    scenario_simulation: Literal["NOT_SUPPORTED"] = "NOT_SUPPORTED"
    calibrated_probability: Literal["NOT_SUPPORTED"] = "NOT_SUPPORTED"
    live_coordinate_inference: Literal["NOT_SUPPORTED"] = "NOT_SUPPORTED"


class ModelCapabilities(BaseModel):
    model_config = ConfigDict(extra="forbid")

    contract_version: Literal["0.1.0"] = "0.1.0"
    implementation_status: Literal[
        "SPECIFICATION_ONLY", "IMPLEMENTED_UNVALIDATED", "RUNTIME_VALIDATED"
    ]
    evidence_status: Literal["NO_TRUSTED_RESULT"] = "NO_TRUSTED_RESULT"
    score_kind: Literal["structural_report_hotspot_ranking"] = (
        "structural_report_hotspot_ranking"
    )
    capabilities: Capabilities
    limitations: list[str] = Field(default_factory=list)
