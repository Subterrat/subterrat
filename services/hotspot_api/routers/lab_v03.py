from __future__ import annotations

from fastapi import APIRouter, Depends, Query

from services.hotspot_api.config import Settings, get_settings
from services.hotspot_api.dependencies import (
    get_v03_cells_repository,
    get_v03_evaluation_repository,
)
from services.hotspot_api.errors import ApiError
from services.hotspot_api.repositories.v03_cells_repo import V03CellsRepository
from services.hotspot_api.repositories.v03_evaluation_repo import (
    V03EvaluationRepository,
)
from services.hotspot_api.schemas.lab_v03 import (
    V03EvaluationSummaryResponse,
    V03LabFeatureCollection,
)
from services.hotspot_api.validation import parse_bbox


router = APIRouter(tags=["Research Lab"])


def _require_internal_lab(settings: Settings) -> None:
    if not settings.lab_v03_enabled:
        raise ApiError(
            404,
            "CAPABILITY_NOT_AVAILABLE",
            "the v0.3 internal-research lab endpoint is disabled",
        )


@router.get("/api/v1/lab/v0.3/cells", response_model=V03LabFeatureCollection)
def list_v03_lab_cells(
    bbox: str = Query(...),
    limit: int | None = Query(default=None, ge=1),
    page_token: str | None = Query(default=None),
    settings: Settings = Depends(get_settings),
    repository: V03CellsRepository = Depends(get_v03_cells_repository),
) -> V03LabFeatureCollection:
    _require_internal_lab(settings)
    parsed_bbox = parse_bbox(bbox)
    effective_limit = min(limit or 500, settings.max_features_per_request)
    return repository.list_cells(parsed_bbox, effective_limit, page_token)


@router.get(
    "/api/v1/lab/v0.3/evaluation-summary",
    response_model=V03EvaluationSummaryResponse,
)
def get_v03_evaluation_summary(
    settings: Settings = Depends(get_settings),
    repository: V03EvaluationRepository = Depends(
        get_v03_evaluation_repository
    ),
) -> V03EvaluationSummaryResponse:
    _require_internal_lab(settings)
    try:
        return repository.get_summary()
    except (KeyError, TypeError, ValueError) as exc:
        raise ApiError(
            503,
            "DATA_GATE_FAILED",
            "the v0.3 evaluation summary failed its aggregate serving contract",
        ) from exc
