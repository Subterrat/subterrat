from __future__ import annotations

from fastapi import APIRouter, Depends, Query

from services.hotspot_api.config import Settings, get_settings
from services.hotspot_api.dependencies import get_v03_cells_repository
from services.hotspot_api.errors import ApiError
from services.hotspot_api.repositories.v03_cells_repo import V03CellsRepository
from services.hotspot_api.schemas.lab_v03 import V03LabFeatureCollection
from services.hotspot_api.validation import parse_bbox


router = APIRouter(tags=["Research Lab"])


@router.get("/api/v1/lab/v0.3/cells", response_model=V03LabFeatureCollection)
def list_v03_lab_cells(
    bbox: str = Query(...),
    limit: int | None = Query(default=None, ge=1),
    page_token: str | None = Query(default=None),
    settings: Settings = Depends(get_settings),
    repository: V03CellsRepository = Depends(get_v03_cells_repository),
) -> V03LabFeatureCollection:
    if not settings.lab_v03_enabled:
        raise ApiError(
            404,
            "CAPABILITY_NOT_AVAILABLE",
            "the v0.3 internal-simulation lab endpoint is disabled",
        )
    parsed_bbox = parse_bbox(bbox)
    effective_limit = min(limit or 500, settings.max_features_per_request)
    return repository.list_cells(parsed_bbox, effective_limit, page_token)
