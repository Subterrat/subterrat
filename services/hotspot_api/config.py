from __future__ import annotations

import os
from dataclasses import dataclass
from functools import lru_cache


def _split_csv(value: str) -> tuple[str, ...]:
    return tuple(item.strip() for item in value.split(",") if item.strip())


@dataclass(frozen=True)
class Settings:
    project_id: str
    bq_location: str
    bq_dataset: str
    bq_table: str
    bq_v03_table: str
    bq_v03_evaluation_table: str
    bq_simulations_dataset: str
    bq_network_map_table: str
    bq_network_state_table: str
    bq_network_links_table: str
    bq_network_receipt_table: str
    release_id: str
    lab_v03_enabled: bool
    max_features_per_request: int
    cors_allow_origins: tuple[str, ...]

    @property
    def table_ref(self) -> str:
        return f"{self.project_id}.{self.bq_dataset}.{self.bq_table}"

    @property
    def v03_table_ref(self) -> str:
        return f"{self.project_id}.{self.bq_dataset}.{self.bq_v03_table}"

    @property
    def v03_evaluation_table_ref(self) -> str:
        return (
            f"{self.project_id}.{self.bq_dataset}."
            f"{self.bq_v03_evaluation_table}"
        )

    @property
    def network_map_table_ref(self) -> str:
        return (
            f"{self.project_id}.{self.bq_simulations_dataset}."
            f"{self.bq_network_map_table}"
        )

    @property
    def network_state_table_ref(self) -> str:
        return (
            f"{self.project_id}.{self.bq_simulations_dataset}."
            f"{self.bq_network_state_table}"
        )

    @property
    def network_links_table_ref(self) -> str:
        return (
            f"{self.project_id}.{self.bq_simulations_dataset}."
            f"{self.bq_network_links_table}"
        )

    @property
    def network_receipt_table_ref(self) -> str:
        return (
            f"{self.project_id}.{self.bq_simulations_dataset}."
            f"{self.bq_network_receipt_table}"
        )


@lru_cache
def get_settings() -> Settings:
    # Env var names match GitHub issue #4's "Runtime 設定" section.
    return Settings(
        project_id=os.environ.get("GOOGLE_CLOUD_PROJECT", "devjam26aug17tpe-1270"),
        bq_location=os.environ.get("BQ_LOCATION", "asia-east1"),
        bq_dataset=os.environ.get("BQ_DATASET", "subterrat_predictions"),
        bq_table=os.environ.get("BQ_TABLE", "map_hotspot_cells_t0"),
        bq_v03_table=os.environ.get(
            "BQ_V03_TABLE", "map_hotspot_cells_v0_3_internal_simulation"
        ),
        bq_v03_evaluation_table=os.environ.get(
            "BQ_V03_EVALUATION_TABLE",
            "hotspot_evaluation_summary_v0_3_internal_simulation",
        ),
        bq_simulations_dataset=os.environ.get(
            "BQ_SIMULATIONS_DATASET", "subterrat_simulations"
        ),
        bq_network_map_table=os.environ.get(
            "BQ_NETWORK_MAP_TABLE",
            "map_synthetic_network_cells_v0_3_internal_simulation",
        ),
        bq_network_state_table=os.environ.get(
            "BQ_NETWORK_STATE_TABLE",
            "synthetic_network_states_v0_3_internal_simulation",
        ),
        bq_network_links_table=os.environ.get(
            "BQ_NETWORK_LINKS_TABLE",
            "schematic_cell_links_v0_3_internal_simulation",
        ),
        bq_network_receipt_table=os.environ.get(
            "BQ_NETWORK_RECEIPT_TABLE",
            "synthetic_network_run_receipt_v0_3_internal_simulation",
        ),
        release_id=os.environ.get(
            "RELEASE_ID", "t0-layerwise-development-20260817-v2"
        ),
        lab_v03_enabled=os.environ.get("LAB_V03_ENABLED", "false").lower()
        in {"1", "true", "yes"},
        max_features_per_request=int(
            os.environ.get("MAX_FEATURES_PER_REQUEST", "1500")
        ),
        cors_allow_origins=_split_csv(os.environ.get("PUBLIC_CORS_ORIGINS", "")),
    )
