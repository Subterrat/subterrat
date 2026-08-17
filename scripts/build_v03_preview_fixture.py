#!/usr/bin/env python3
"""Convert a BigQuery read-only v0.3 result into a local React fixture."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCENARIO_ID = "v0_3_equal_group_internal_simulation_r150"
RELEASE_STATE = "READ_ONLY_PREVIEW_UNCOMMITTED"
LIMITATION_CODES = [
    "NO_TRUSTED_RESULT",
    "OPERATIONAL_USE_PROHIBITED",
    "V0_2_SEWER_GATES_INCOMPLETE",
    "URBAN_RENEWAL_SOURCE_REUSE_LICENSE_INCOMPLETE",
    "URBAN_RENEWAL_STATUS_TAXONOMY_AND_TEMPORAL_MEANING_INCOMPLETE",
    "PREVIEW_UNCOMMITTED_STATIC_FIXTURE",
    "MISSING_SUPPORT_NOT_LOW_SCORE",
    "ORDINAL_SIMULATION_INDEX_NOT_PROBABILITY",
]


def _number(row: dict[str, Any], key: str) -> float | None:
    value = row.get(key)
    return None if value is None else float(value)


def _boolean(row: dict[str, Any], key: str) -> bool:
    value = row.get(key)
    if isinstance(value, bool):
        return value
    if value == "true":
        return True
    if value == "false":
        return False
    raise ValueError(f"{key} must be a boolean")


def _feature(row: dict[str, Any], source_job_id: str) -> dict[str, Any]:
    for key, expected in (
        ("use_state", "INTERNAL_SIMULATION_ONLY"),
        ("evidence_state", "NO_TRUSTED_RESULT"),
        ("operational_use", "PROHIBITED"),
        ("score_semantics", "ORDINAL_SIMULATION_INDEX_NOT_PROBABILITY"),
    ):
        if row.get(key) != expected:
            raise ValueError(f"unexpected {key} for cell {row.get('cell_id')}")

    support_state = row.get("support_state")
    if support_state not in {
        "SCORED_COMPLETE_CASE",
        "MISSING_SEWER_COMPLETE_CASE",
    }:
        raise ValueError(f"unexpected support_state for cell {row.get('cell_id')}")

    cell_id = str(row["cell_id"])
    geometry = json.loads(row["eligible_geojson"])
    if geometry.get("type") not in {"Polygon", "MultiPolygon"}:
        raise ValueError(f"unsupported geometry for cell {cell_id}")

    return {
        "type": "Feature",
        "id": cell_id,
        "geometry": geometry,
        "properties": {
            "cell_id": cell_id,
            "centroid_longitude": _number(row, "centroid_longitude"),
            "centroid_latitude": _number(row, "centroid_latitude"),
            "scenario_id": SCENARIO_ID,
            "release_state": RELEASE_STATE,
            "score_semantics": "ORDINAL_SIMULATION_INDEX_NOT_PROBABILITY",
            "specification_state": "PENDING_COMMITTED_LOCK",
            "use_state": "INTERNAL_SIMULATION_ONLY",
            "evidence_state": "NO_TRUSTED_RESULT",
            "operational_use": "PROHIBITED",
            "calibrated_probability": None,
            "scenario_state": "READ_ONLY_PREVIEW_EQUAL_GROUP_R150",
            "support_state": support_state,
            "total_cell_count": 3420,
            "scoreable_city_area_share": _number(
                row, "scoreable_city_area_share"
            ),
            "rank_within_scoreable_support": _number(
                row, "rank_within_scoreable_support"
            ),
            "preregistered_selected_scenario_area": _boolean(
                row, "selected_scenario_area_flag"
            ),
            "preview_source_job_id": source_job_id,
            "scores": {
                "food_market_v0_1": _number(row, "food_score"),
                "sewer_system_type_v0_1": _number(
                    row, "sewer_system_type_score"
                ),
                "sewer_system_type_v0_2": _number(
                    row, "sewer_system_type_diagnostic"
                ),
                "surface_elevation_v0_2": _number(
                    row, "surface_elevation_diagnostic"
                ),
                "connected_pipe_diameter_v0_2": _number(
                    row, "connected_pipe_diameter_diagnostic"
                ),
                "connected_pipe_depth_v0_2": _number(
                    row, "connected_pipe_depth_diagnostic"
                ),
                "connected_pipe_age_v0_2": _number(
                    row, "connected_pipe_age_diagnostic"
                ),
                "sewer_attribute_index_v0_2": _number(
                    row, "sewer_attribute_index"
                ),
                "approved_rebuilding_admin_site_buffer_0m": _number(
                    row, "approved_rebuilding_admin_site_r0"
                ),
                "approved_rebuilding_admin_site_buffer_150m": _number(
                    row, "approved_rebuilding_admin_site_r150"
                ),
                "approved_rebuilding_admin_site_buffer_300m": _number(
                    row, "approved_rebuilding_admin_site_r300"
                ),
                "v0_3_equal_group_internal_simulation_r150": _number(
                    row, "v0_3_equal_group_index_r150"
                ),
            },
            "limitation_codes": LIMITATION_CODES
            + (
                ["SEWER_COMPLETE_CASE_MISSING"]
                if support_state == "MISSING_SEWER_COMPLETE_CASE"
                else []
            ),
        },
    }


def build_fixture(
    input_path: Path, output_path: Path, source_job_id: str
) -> dict[str, Any]:
    rows = json.loads(input_path.read_text(encoding="utf-8"))
    if not isinstance(rows, list) or len(rows) != 3420:
        raise ValueError("BigQuery preview must contain exactly 3,420 rows")

    features = [_feature(row, source_job_id) for row in rows]
    features.sort(key=lambda feature: int(feature["id"]))
    if len({feature["id"] for feature in features}) != 3420:
        raise ValueError("BigQuery preview cell ids must be unique")

    scoreable_cells = sum(
        feature["properties"]["scores"][
            "v0_3_equal_group_internal_simulation_r150"
        ]
        is not None
        for feature in features
    )
    if scoreable_cells != 1589:
        raise ValueError("BigQuery preview must contain exactly 1,589 scored cells")

    payload = {
        "type": "FeatureCollection",
        "scenario_id": SCENARIO_ID,
        "release_state": RELEASE_STATE,
        "source_job_id": source_job_id,
        "scoreable_cells": scoreable_cells,
        "total_cells": 3420,
        "scoreable_city_area_share": _number(rows[0], "scoreable_city_area_share"),
        "features": features,
        "next_page_token": None,
        "truncated": False,
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(payload, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )
    return payload


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--source-job-id", required=True)
    args = parser.parse_args()
    payload = build_fixture(args.input, args.output, args.source_job_id)
    print(
        json.dumps(
            {
                "source_job_id": payload["source_job_id"],
                "features": len(payload["features"]),
                "scoreable_city_area_share": payload["scoreable_city_area_share"],
                "output": str(args.output),
            },
            ensure_ascii=False,
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
