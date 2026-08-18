from __future__ import annotations

import base64
import json
from typing import Any

from google.cloud import bigquery

from services.hotspot_api.bigquery_gateway import BigQueryGateway
from services.hotspot_api.schemas.common import GeoJsonMultiPolygon, GeoJsonPolygon
from services.hotspot_api.schemas.lab_v03 import (
    V03LabCellFeature,
    V03LabCellProperties,
    V03LabFeatureCollection,
    V03Scores,
)


_COLUMNS = (
    "cell_id",
    "eligible_geojson",
    "centroid_longitude",
    "centroid_latitude",
    "food_score",
    "sewer_system_type_score",
    "sewer_system_type_diagnostic",
    "surface_elevation_diagnostic",
    "connected_pipe_diameter_diagnostic",
    "connected_pipe_depth_diagnostic",
    "connected_pipe_age_diagnostic",
    "sewer_attribute_index",
    "approved_rebuilding_admin_site_r0",
    "approved_rebuilding_admin_site_r150",
    "approved_rebuilding_admin_site_r300",
    "v0_3_simulation_index",
    "rank_within_scoreable_support",
    "preregistered_selected_scenario_area_flag",
    "scenario_state",
    "specification_state",
    "use_state",
    "operational_use",
    "limitation_codes",
    "scenario_id",
    "release_state",
    "score_semantics",
    "evidence_state",
    "calibrated_probability",
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


def _row_to_feature(row: dict[str, Any]) -> V03LabCellFeature:
    cell_id = str(row["cell_id"])
    properties = V03LabCellProperties(
        cell_id=cell_id,
        centroid_longitude=row["centroid_longitude"],
        centroid_latitude=row["centroid_latitude"],
        scenario_id=row["scenario_id"],
        release_state=row["release_state"],
        score_semantics=row["score_semantics"],
        specification_state=row["specification_state"],
        use_state=row["use_state"],
        evidence_state=row["evidence_state"],
        operational_use=row["operational_use"],
        calibrated_probability=row.get("calibrated_probability"),
        scenario_state=row["scenario_state"],
        rank_within_scoreable_support=row.get("rank_within_scoreable_support"),
        preregistered_selected_scenario_area=bool(
            row.get("preregistered_selected_scenario_area_flag")
        ),
        scores=V03Scores(
            food_market_v0_1=row.get("food_score"),
            sewer_system_type_v0_1=row.get("sewer_system_type_score"),
            sewer_system_type_v0_2=row.get("sewer_system_type_diagnostic"),
            surface_elevation_v0_2=row.get("surface_elevation_diagnostic"),
            connected_pipe_diameter_v0_2=row.get(
                "connected_pipe_diameter_diagnostic"
            ),
            connected_pipe_depth_v0_2=row.get("connected_pipe_depth_diagnostic"),
            connected_pipe_age_v0_2=row.get("connected_pipe_age_diagnostic"),
            sewer_attribute_index_v0_2=row.get("sewer_attribute_index"),
            approved_rebuilding_admin_site_buffer_0m=row.get(
                "approved_rebuilding_admin_site_r0"
            ),
            approved_rebuilding_admin_site_buffer_150m=row.get(
                "approved_rebuilding_admin_site_r150"
            ),
            approved_rebuilding_admin_site_buffer_300m=row.get(
                "approved_rebuilding_admin_site_r300"
            ),
            v0_3_equal_group_internal_simulation_r150=row.get(
                "v0_3_simulation_index"
            ),
        ),
        limitation_codes=list(row.get("limitation_codes") or []),
    )
    return V03LabCellFeature(
        id=cell_id,
        geometry=_parse_geometry(row["eligible_geojson"]),
        properties=properties,
    )


class V03CellsRepository:
    def __init__(self, gateway: BigQueryGateway, table_ref: str) -> None:
        self._gateway = gateway
        self._table_ref = table_ref

    def list_cells(
        self,
        bbox: tuple[float, float, float, float],
        limit: int,
        page_token: str | None,
    ) -> V03LabFeatureCollection:
        west, south, east, north = bbox
        after_cell_id = _decode_page_token(page_token) if page_token else None
        sql = f"""
        SELECT {_SELECT_LIST}
        FROM `{self._table_ref}`
        WHERE scenario_id = 'v0_3_equal_group_internal_simulation_r150'
          AND ST_INTERSECTSBOX(
                SAFE.ST_GEOGFROMGEOJSON(eligible_geojson), @west, @south, @east, @north
              )
          {"AND cell_id > @after_cell_id" if after_cell_id is not None else ""}
        ORDER BY cell_id
        LIMIT @row_limit
        """
        parameters = [
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
        return V03LabFeatureCollection(
            features=features,
            next_page_token=next_page_token,
        )
