from __future__ import annotations

from services.hotspot_api.errors import ApiError


def parse_bbox(raw: str) -> tuple[float, float, float, float]:
    parts = raw.split(",")
    if len(parts) != 4:
        raise ApiError(422, "INVALID_BBOX", "bbox must be 'west,south,east,north'")
    try:
        west, south, east, north = (float(part) for part in parts)
    except ValueError as exc:
        raise ApiError(422, "INVALID_BBOX", "bbox values must be numeric") from exc
    if not (-180 <= west <= 180 and -180 <= east <= 180):
        raise ApiError(422, "INVALID_BBOX", "longitude must be within -180..180")
    if not (-90 <= south <= 90 and -90 <= north <= 90):
        raise ApiError(422, "INVALID_BBOX", "latitude must be within -90..90")
    if west >= east or south >= north:
        raise ApiError(
            422, "INVALID_BBOX", "bbox must satisfy west<east and south<north"
        )
    return west, south, east, north


def parse_cell_id(raw: str) -> str:
    if not raw.isdigit():
        raise ApiError(404, "CELL_NOT_FOUND", f"{raw!r} is not a valid S2 cell id")
    return raw
