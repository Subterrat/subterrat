from __future__ import annotations

import base64
import json
from typing import Any

from google.cloud import bigquery

from services.hotspot_api.bigquery_gateway import BigQueryGateway
from services.hotspot_api.schemas.cells import (
    CellFeature,
    CellFeatureCollection,
    CellProperties,
    RankVariants,
    RawLayerFields,
    ScoreComponents,
)
from services.hotspot_api.schemas.common import GeoJsonMultiPolygon, GeoJsonPolygon

# Allowlisted SELECT columns from `map_hotspot_cells_t0`
# (sql/structural/07_materialize_map_payload.sql). Never `SELECT *`
# (GitHub issue #4 "Query 與效能要求").
_COLUMNS = (
    "cell_id",
    "eligible_geojson",
    "food_score",
    "food_top_area",
    "sewer_score",
    "sewer_top_area",
    "sewer_has_score",
    "sewer_coverage_state",
    "unused_public_building_address_point_count",
    "building_overlay_state",
    "freeze_id",
    "model_kind",
    "score_semantics",
    "evidence_state",
)
_SELECT_LIST = ", ".join(_COLUMNS)


def _encode_page_token(after_cell_id: int) -> str:
    payload = json.dumps({"after_cell_id": after_cell_id}).encode("utf-8")
    return base64.urlsafe_b64encode(payload).decode("ascii")


def _decode_page_token(token: str) -> int:
    payload = json.loads(base64.urlsafe_b64decode(token.encode("ascii")))
    return int(payload["after_cell_id"])


def _parse_geometry(geojson_text: str) -> GeoJsonPolygon | GeoJsonMultiPolygon:
    payload = json.loads(geojson_text)
    if payload["type"] == "Polygon":
        return GeoJsonPolygon(coordinates=payload["coordinates"])
    return GeoJsonMultiPolygon(coordinates=payload["coordinates"])


def _coverage_state(row: dict[str, Any]) -> str:
    if row.get("food_score") is None or row.get("sewer_score") is None:
        return "unscored_missing_group"
    return "eligible"


def _limitation_codes(row: dict[str, Any]) -> list[str]:
    codes = ["NO_TRUSTED_RESULT", "MAIN_SCORE_NOT_COMPUTED_MISSING_ABANDONED_GROUP"]
    if row.get("food_score") is None or row.get("sewer_score") is None:
        codes.append("DATA_GATE_INCOMPLETE_COMPONENT")
    return codes


def _row_to_properties(row: dict[str, Any]) -> CellProperties:
    return CellProperties(
        cell_id=str(row["cell_id"]),
        # map_hotspot_cells_t0 has no prediction_run_id (no official_t0 run
        # exists yet) — freeze_id is the closest real identifier it has.
        prediction_run_id=row["freeze_id"],
        structural_score=None,
        rank_percentile=None,
        components=ScoreComponents(
            food=row.get("food_score"), sewer=row.get("sewer_score"), abandoned=None
        ),
        ranks=RankVariants(),
        top_k=None,
        coverage_state=_coverage_state(row),
        freshness="unknown",
        limitation_codes=_limitation_codes(row),
        raw_layer_fields=RawLayerFields(
            food_top_area=row.get("food_top_area"),
            sewer_top_area=row.get("sewer_top_area"),
            sewer_has_score=row.get("sewer_has_score"),
            sewer_coverage_state=row.get("sewer_coverage_state"),
            unused_public_building_address_point_count=row.get(
                "unused_public_building_address_point_count"
            ),
            building_overlay_state=row.get("building_overlay_state"),
            freeze_id=row.get("freeze_id"),
            model_kind=row.get("model_kind"),
            score_semantics=row.get("score_semantics"),
            evidence_state=row.get("evidence_state"),
        ),
    )


def _row_to_feature(row: dict[str, Any]) -> CellFeature:
    return CellFeature(
        id=str(row["cell_id"]),
        geometry=_parse_geometry(row["eligible_geojson"]),
        properties=_row_to_properties(row),
    )


class CellsRepository:
    def __init__(self, gateway: BigQueryGateway, table_ref: str) -> None:
        self._gateway = gateway
        self._table_ref = table_ref

    def list_cells(
        self,
        release_id: str,
        bbox: tuple[float, float, float, float],
        limit: int,
        page_token: str | None,
    ) -> CellFeatureCollection:
        west, south, east, north = bbox
        after_cell_id = _decode_page_token(page_token) if page_token else None
        sql = f"""
        SELECT {_SELECT_LIST}
        FROM `{self._table_ref}`
        WHERE freeze_id = @release_id
          AND ST_INTERSECTSBOX(
                SAFE.ST_GEOGFROMGEOJSON(eligible_geojson), @south, @west, @north, @east
              )
          {"AND cell_id > @after_cell_id" if after_cell_id is not None else ""}
        ORDER BY cell_id
        LIMIT @row_limit
        """
        parameters = [
            bigquery.ScalarQueryParameter("release_id", "STRING", release_id),
            bigquery.ScalarQueryParameter("south", "FLOAT64", south),
            bigquery.ScalarQueryParameter("west", "FLOAT64", west),
            bigquery.ScalarQueryParameter("north", "FLOAT64", north),
            bigquery.ScalarQueryParameter("east", "FLOAT64", east),
            bigquery.ScalarQueryParameter("row_limit", "INT64", limit + 1),
        ]
        if after_cell_id is not None:
            parameters.append(
                bigquery.ScalarQueryParameter("after_cell_id", "INT64", after_cell_id)
            )
        rows = self._gateway.query(sql, parameters)
        has_more = len(rows) > limit
        rows = rows[:limit]
        features = [_row_to_feature(row) for row in rows]
        next_page_token = (
            _encode_page_token(int(rows[-1]["cell_id"])) if has_more and rows else None
        )
        return CellFeatureCollection(
            release_id=release_id,
            prediction_run_id=release_id,
            features=features,
            next_page_token=next_page_token,
        )

    def get_cell(self, release_id: str, cell_id: str) -> CellFeature | None:
        sql = f"""
        SELECT {_SELECT_LIST}
        FROM `{self._table_ref}`
        WHERE freeze_id = @release_id
          AND cell_id = @cell_id
        LIMIT 1
        """
        parameters = [
            bigquery.ScalarQueryParameter("release_id", "STRING", release_id),
            bigquery.ScalarQueryParameter("cell_id", "INT64", int(cell_id)),
        ]
        rows = self._gateway.query(sql, parameters)
        return _row_to_feature(rows[0]) if rows else None
