from __future__ import annotations

from functools import lru_cache

from fastapi import Depends

from services.hotspot_api.bigquery_gateway import BigQueryGateway
from services.hotspot_api.config import Settings, get_settings
from services.hotspot_api.repositories.cells_repo import CellsRepository
from services.hotspot_api.repositories.network_redistribution_repo import (
    NetworkRedistributionRepository,
)
from services.hotspot_api.repositories.v03_cells_repo import V03CellsRepository
from services.hotspot_api.repositories.v03_evaluation_repo import (
    V03EvaluationRepository,
)
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


def get_v03_cells_repository(
    gateway: BigQueryGateway = Depends(get_bigquery_gateway),
    settings: Settings = Depends(get_settings),
) -> V03CellsRepository:
    return V03CellsRepository(gateway, settings.v03_table_ref)


def get_v03_evaluation_repository(
    gateway: BigQueryGateway = Depends(get_bigquery_gateway),
    settings: Settings = Depends(get_settings),
) -> V03EvaluationRepository:
    return V03EvaluationRepository(gateway, settings.v03_evaluation_table_ref)


def get_network_redistribution_repository(
    gateway: BigQueryGateway = Depends(get_bigquery_gateway),
    settings: Settings = Depends(get_settings),
) -> NetworkRedistributionRepository:
    return NetworkRedistributionRepository(
        gateway,
        settings.network_map_table_ref,
        settings.network_state_table_ref,
        settings.network_links_table_ref,
        settings.network_receipt_table_ref,
    )
