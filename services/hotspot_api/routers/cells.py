from __future__ import annotations

from fastapi import APIRouter, Depends, Query

from services.hotspot_api.config import Settings, get_settings
from services.hotspot_api.dependencies import get_cells_repository, get_releases_repository
from services.hotspot_api.errors import ApiError
from services.hotspot_api.repositories.cells_repo import CellsRepository
from services.hotspot_api.repositories.releases_repo import ReleasesRepository
from services.hotspot_api.schemas.cells import CellFeature, CellFeatureCollection
from services.hotspot_api.validation import parse_bbox, parse_cell_id

router = APIRouter(tags=["Map", "Predictions"])


@router.get("/api/v1/releases/{release_id}/cells", response_model=CellFeatureCollection)
def list_release_cells(
    release_id: str,
    bbox: str = Query(...),
    limit: int | None = Query(default=None, ge=1),
    page_token: str | None = Query(default=None),
    releases_repo: ReleasesRepository = Depends(get_releases_repository),
    cells_repo: CellsRepository = Depends(get_cells_repository),
    settings: Settings = Depends(get_settings),
) -> CellFeatureCollection:
    if not releases_repo.is_readable(release_id):
        raise ApiError(404, "RELEASE_NOT_FOUND", f"release {release_id!r} was not found")
    parsed_bbox = parse_bbox(bbox)
    effective_limit = min(limit or 500, settings.max_features_per_request)
    return cells_repo.list_cells(release_id, parsed_bbox, effective_limit, page_token)


@router.get(
    "/api/v1/releases/{release_id}/cells/{cell_id}", response_model=CellFeature
)
def get_release_cell(
    release_id: str,
    cell_id: str,
    releases_repo: ReleasesRepository = Depends(get_releases_repository),
    cells_repo: CellsRepository = Depends(get_cells_repository),
) -> CellFeature:
    if not releases_repo.is_readable(release_id):
        raise ApiError(404, "RELEASE_NOT_FOUND", f"release {release_id!r} was not found")
    parsed_cell_id = parse_cell_id(cell_id)
    cell = cells_repo.get_cell(release_id, parsed_cell_id)
    if cell is None:
        raise ApiError(
            404,
            "CELL_NOT_FOUND",
            f"cell {cell_id!r} was not found in release {release_id!r}",
        )
    return cell
