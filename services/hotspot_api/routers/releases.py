from __future__ import annotations

from fastapi import APIRouter, Depends

from services.hotspot_api.dependencies import get_releases_repository
from services.hotspot_api.errors import ApiError
from services.hotspot_api.repositories.releases_repo import ReleasesRepository
from services.hotspot_api.schemas.releases import CurrentRelease

router = APIRouter(tags=["Releases"])


@router.get("/api/v1/releases/current", response_model=CurrentRelease)
def get_current_release(
    releases_repo: ReleasesRepository = Depends(get_releases_repository),
) -> CurrentRelease:
    release_id = releases_repo.current_release_id()
    if not releases_repo.is_readable(release_id):
        raise ApiError(
            404, "NO_PUBLISHED_RELEASE", "no human-approved public release is available"
        )
    # Points at /cells, not /releases/{release_id}: this MVP (GitHub issue
    # #4) does not implement the release-metadata-detail endpoint, so a
    # release_id-only href would 404.
    return CurrentRelease(
        release_id=release_id, href=f"/api/v1/releases/{release_id}/cells"
    )
