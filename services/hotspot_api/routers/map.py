from __future__ import annotations

from fastapi import APIRouter, Depends

from services.hotspot_api.dependencies import get_releases_repository
from services.hotspot_api.errors import ApiError
from services.hotspot_api.repositories.releases_repo import ReleasesRepository
from services.hotspot_api.schemas.common import Bounds, Camera
from services.hotspot_api.schemas.map import LayerAvailability, MapBootstrap

router = APIRouter(tags=["Map"])

_TAIPEI_BOUNDS = Bounds(west=121.4577, south=24.9613, east=121.6656, north=25.2107)
_DEFAULT_CAMERA = Camera(latitude=25.0478, longitude=121.5319, zoom=11)


@router.get("/api/v1/map/bootstrap", response_model=MapBootstrap)
def get_map_bootstrap(
    releases_repo: ReleasesRepository = Depends(get_releases_repository),
) -> MapBootstrap:
    release_id = releases_repo.current_release_id()
    if not releases_repo.is_readable(release_id):
        raise ApiError(
            404, "NO_PUBLISHED_RELEASE", "no human-approved public release is available"
        )
    return MapBootstrap(
        current_release_id=release_id,
        taipei_bounds=_TAIPEI_BOUNDS,
        default_camera=_DEFAULT_CAMERA,
        layers=[
            LayerAvailability(
                id="structural_score",
                label="Structural hotspot score",
                availability="available",
            ),
            LayerAvailability(
                id="data_coverage", label="Data coverage", availability="available"
            ),
            LayerAvailability(
                id="approved_report_count",
                label="Approved report count",
                availability="withheld",
                reason="outcome release requires human approval",
            ),
        ],
        limitation_codes=[
            "NO_TRUSTED_RESULT",
            "MAIN_SCORE_NOT_COMPUTED_MISSING_ABANDONED_GROUP",
        ],
    )
