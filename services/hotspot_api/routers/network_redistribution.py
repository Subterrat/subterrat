from __future__ import annotations

from fastapi import APIRouter, Depends, Query

from services.hotspot_api.config import Settings, get_settings
from services.hotspot_api.dependencies import (
    get_network_redistribution_repository,
)
from services.hotspot_api.errors import ApiError
from services.hotspot_api.repositories.network_redistribution_repo import (
    NetworkRedistributionRepository,
)
from services.hotspot_api.schemas.network_redistribution import (
    NetworkCellsResponse,
    NetworkLinksResponse,
    NetworkScenarioId,
)


router = APIRouter(tags=["Research Lab"])


def _require_internal_lab(settings: Settings) -> None:
    if not settings.lab_v03_enabled:
        raise ApiError(
            404,
            "CAPABILITY_NOT_AVAILABLE",
            "the v0.3 internal synthetic network redistribution endpoint is disabled",
        )


@router.get(
    "/api/v1/lab/v0.3/network-redistribution/cells",
    response_model=NetworkCellsResponse,
)
def list_network_redistribution_cells(
    scenario_id: NetworkScenarioId = Query(...),
    abstract_iteration: int = Query(..., ge=0, le=8),
    settings: Settings = Depends(get_settings),
    repository: NetworkRedistributionRepository = Depends(
        get_network_redistribution_repository
    ),
) -> NetworkCellsResponse:
    _require_internal_lab(settings)
    return repository.list_cells(scenario_id, abstract_iteration)


@router.get(
    "/api/v1/lab/v0.3/network-redistribution/links",
    response_model=NetworkLinksResponse,
)
def list_network_redistribution_links(
    scenario_id: NetworkScenarioId = Query(...),
    settings: Settings = Depends(get_settings),
    repository: NetworkRedistributionRepository = Depends(
        get_network_redistribution_repository
    ),
) -> NetworkLinksResponse:
    _require_internal_lab(settings)
    return repository.list_links(scenario_id)
