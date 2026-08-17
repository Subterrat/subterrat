from __future__ import annotations

from fastapi import APIRouter, Depends

from services.hotspot_api.dependencies import get_releases_repository
from services.hotspot_api.errors import ApiError
from services.hotspot_api.repositories.releases_repo import ReleasesRepository
from services.hotspot_api.schemas.operations import Health, Readiness

router = APIRouter(tags=["Operations"])


@router.get("/healthz", response_model=Health)
def get_health() -> Health:
    return Health()


@router.get("/readyz", response_model=Readiness)
def get_readiness(
    releases_repo: ReleasesRepository = Depends(get_releases_repository),
) -> Readiness:
    release_id = releases_repo.current_release_id()
    if not releases_repo.is_readable(release_id):
        raise ApiError(
            503, "NO_PUBLISHED_RELEASE", "serving table is not readable right now"
        )
    return Readiness(current_release_id=release_id)
