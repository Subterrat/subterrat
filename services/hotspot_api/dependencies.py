from __future__ import annotations

from functools import lru_cache

from fastapi import Depends

from services.hotspot_api.bigquery_gateway import BigQueryGateway
from services.hotspot_api.config import Settings, get_settings
from services.hotspot_api.repositories.cells_repo import CellsRepository
from services.hotspot_api.repositories.releases_repo import ReleasesRepository


@lru_cache
def _get_gateway(project_id: str, location: str) -> BigQueryGateway:
    return BigQueryGateway(project_id, location)


def get_bigquery_gateway(
    settings: Settings = Depends(get_settings),
) -> BigQueryGateway:
    return _get_gateway(settings.project_id, settings.bq_location)


def get_releases_repository(
    gateway: BigQueryGateway = Depends(get_bigquery_gateway),
    settings: Settings = Depends(get_settings),
) -> ReleasesRepository:
    return ReleasesRepository(gateway, settings.table_ref, settings.release_id)


def get_cells_repository(
    gateway: BigQueryGateway = Depends(get_bigquery_gateway),
    settings: Settings = Depends(get_settings),
) -> CellsRepository:
    return CellsRepository(gateway, settings.table_ref)
