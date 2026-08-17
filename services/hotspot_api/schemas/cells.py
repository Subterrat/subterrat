from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from services.hotspot_api.schemas.common import (
    ForecastWindow,
    GeoJsonMultiPolygon,
    GeoJsonPolygon,
)


class ScoreComponents(BaseModel):
    model_config = ConfigDict(extra="forbid")

    food: float | None = Field(None, ge=0, le=1)
    sewer: float | None = Field(None, ge=0, le=1)
    abandoned: float | None = Field(None, ge=0, le=1)


class RankVariants(BaseModel):
    model_config = ConfigDict(extra="forbid")

    main: int | None = Field(None, ge=1)
    food_only: int | None = Field(None, ge=1)
    without_food: int | None = Field(None, ge=1)
    without_sewer: int | None = Field(None, ge=1)
    without_abandoned: int | None = Field(None, ge=1)


class TopKFlags(BaseModel):
    model_config = ConfigDict(extra="forbid")

    top_05: bool
    top_10: bool
    top_20: bool


class ReleasedOutcomeSummary(BaseModel):
    model_config = ConfigDict(extra="forbid")

    availability: Literal["released", "withheld", "not_observed"]
    suppressed: bool
    approved_report_count: int | None = Field(None, ge=0)
    count_band: str | None = None
    observation_window: ForecastWindow | None = None
    field_verified: Literal[False] = False


class RawLayerFields(BaseModel):
    """Passthrough of `map_hotspot_cells_t0` columns that GitHub issue #4's
    "Cell response 允許欄位" list names explicitly, but that don't map onto
    any field in the contract's modeled CellProperties (which assumes a
    combined three-group MainScore and integer ranks this v0.1 table does
    not have — see sql/structural/07_materialize_map_payload.sql). Kept as
    its own labeled object instead of loosening CellProperties itself, so
    "real contract field" and "raw v0.1 table passthrough" stay visually
    distinct in the response.
    """

    model_config = ConfigDict(extra="forbid")

    food_top_area: bool | None = None
    sewer_top_area: bool | None = None
    sewer_has_score: bool | None = None
    sewer_coverage_state: str | None = None
    unused_public_building_address_point_count: int | None = Field(None, ge=0)
    building_overlay_state: str | None = None
    freeze_id: str | None = None
    model_kind: str | None = None
    score_semantics: str | None = None
    evidence_state: str | None = None


class CellProperties(BaseModel):
    model_config = ConfigDict(extra="forbid")

    cell_id: str = Field(..., pattern=r"^[0-9]+$")
    prediction_run_id: str
    score_kind: Literal["structural_report_hotspot_ranking"] = (
        "structural_report_hotspot_ranking"
    )
    # null today: this v0.1 freeze only has two of the three required
    # feature groups ranked (abandoned buildings are overlay-only, not a
    # citywide ranked layer — contracts/structural_score_v0_1.json
    # layerwise_policy.missing_layer_action = PUBLISH_BLOCKED_STATUS_NOT_IMPUTED_SCORE),
    # so a combined structural_score/rank_percentile/top_k cannot be
    # honestly computed yet.
    structural_score: float | None = Field(None, ge=0, le=1)
    rank_percentile: float | None = Field(None, ge=0, le=1)
    calibrated_probability: None = None
    components: ScoreComponents
    ranks: RankVariants
    top_k: TopKFlags | None = None
    coverage_state: Literal[
        "eligible", "unscored_missing_group", "excluded_boundary", "withheld"
    ]
    freshness: Literal["current", "stale", "unknown"]
    limitation_codes: list[str] = Field(..., min_length=1)
    released_outcome: ReleasedOutcomeSummary | None = None
    raw_layer_fields: RawLayerFields | None = None


class CellFeature(BaseModel):
    model_config = ConfigDict(extra="forbid")

    type: Literal["Feature"] = "Feature"
    id: str = Field(..., pattern=r"^[0-9]+$")
    geometry: GeoJsonPolygon | GeoJsonMultiPolygon
    properties: CellProperties


class CellFeatureCollection(BaseModel):
    model_config = ConfigDict(extra="forbid")

    type: Literal["FeatureCollection"] = "FeatureCollection"
    release_id: str
    prediction_run_id: str
    # null today: this v0.1 freeze is a development-exposed retrospective
    # layerwise benchmark, not an official_t0 run with a real target
    # observation window (docs/V0_1_RUNBOOK.md) — fabricating dates here
    # would violate the no-fabrication rule in docs/BELIEF.md.
    target_window: ForecastWindow | None = None
    features: list[CellFeature] = Field(default_factory=list, max_length=1500)
    next_page_token: str | None = None
    truncated: Literal[False] = False
