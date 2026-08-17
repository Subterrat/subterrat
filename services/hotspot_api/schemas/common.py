from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

# Keep in sync with docs/openapi-v1.yaml components.schemas.Problem.code.
ErrorCode = Literal[
    "NO_PUBLISHED_RELEASE",
    "RELEASE_NOT_FOUND",
    "CELL_NOT_FOUND",
    "PREDICTION_RUN_NOT_FOUND",
    "INVALID_BBOX",
    "INVALID_TIME_WINDOW",
    "CAPABILITY_NOT_AVAILABLE",
    "DATA_GATE_FAILED",
    "STATE_CONFLICT",
    "IDEMPOTENCY_CONFLICT",
    "FORBIDDEN_DATA_SCOPE",
    "INTERNAL_ERROR",
]


class Problem(BaseModel):
    model_config = ConfigDict(extra="forbid")

    type: str
    title: str
    status: int = Field(..., ge=400, le=599)
    code: ErrorCode
    detail: str
    request_id: str


class ForecastWindow(BaseModel):
    model_config = ConfigDict(extra="forbid")

    start: str
    end: str


class Bounds(BaseModel):
    model_config = ConfigDict(extra="forbid")

    west: float = Field(..., ge=-180, le=180)
    south: float = Field(..., ge=-90, le=90)
    east: float = Field(..., ge=-180, le=180)
    north: float = Field(..., ge=-90, le=90)


class Camera(BaseModel):
    model_config = ConfigDict(extra="forbid")

    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    zoom: float = Field(..., ge=0, le=24)


Position = tuple[float, float]


class GeoJsonPolygon(BaseModel):
    model_config = ConfigDict(extra="forbid")

    type: Literal["Polygon"] = "Polygon"
    coordinates: list[list[Position]]


class GeoJsonMultiPolygon(BaseModel):
    model_config = ConfigDict(extra="forbid")

    type: Literal["MultiPolygon"] = "MultiPolygon"
    coordinates: list[list[list[Position]]]
