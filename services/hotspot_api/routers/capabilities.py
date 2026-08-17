from __future__ import annotations

from fastapi import APIRouter

from services.hotspot_api.schemas.capabilities import Capabilities, ModelCapabilities

router = APIRouter(tags=["Capabilities"])

# Matches docs/API_CONTRACT.md section 3's capability matrix.
_CAPABILITIES = Capabilities(
    spatial_ranking="PLANNED",
    forecast_window="PLANNED",
    forecast_vintage_history="PLANNED",
    aggregated_released_outcome="CONDITIONAL",
)


@router.get("/api/v1/model-capabilities", response_model=ModelCapabilities)
def get_model_capabilities() -> ModelCapabilities:
    return ModelCapabilities(
        implementation_status="IMPLEMENTED_UNVALIDATED",
        capabilities=_CAPABILITIES,
        limitations=[
            "calibrated_probability is always null: scores are structural "
            "hotspot rankings, not rat-presence probabilities",
            "no human-approved public release exists yet",
        ],
    )
