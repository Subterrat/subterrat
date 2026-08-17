from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from services.hotspot_api.schemas.common import Bounds, Camera

LayerId = Literal["structural_score", "data_coverage", "approved_report_count"]


class LayerAvailability(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: LayerId
    label: str
    availability: Literal["available", "withheld", "not_produced"]
    reason: str | None = None


class MapBootstrap(BaseModel):
    model_config = ConfigDict(extra="forbid")

    api_version: Literal["v1"] = "v1"
    current_release_id: str
    taipei_bounds: Bounds
    default_camera: Camera
    layers: list[LayerAvailability]
    evidence_status: Literal["NO_TRUSTED_RESULT"] = "NO_TRUSTED_RESULT"
    claim_scope: Literal["future_approved_citizen_report_hotspot_ranking"] = (
        "future_approved_citizen_report_hotspot_ranking"
    )
    limitation_codes: list[str] = Field(default_factory=list)
