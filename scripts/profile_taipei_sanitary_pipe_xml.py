#!/usr/bin/env python3
"""Profile Taipei sanitary-pipe XML shards without reading outcome data.

The script is a data-gate utility. It preserves the distinction between raw
official reference data and a model-ready feature. It does not score cells,
read Rat Radar, or choose cleaning thresholds from an outcome.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import xml.etree.ElementTree as ET
from collections import Counter
from datetime import date
from pathlib import Path
from typing import Iterable


DIAMETER_UNIT_TO_METRES = {
    "0": 0.001,  # mm
    "1": 0.0254,  # inch
    "2": 0.01,  # cm
    "3": 1.0,  # m
}

TEXT_FIELDS = (
    "識別碼",
    "起點編號",
    "終點編號",
    "管理單位",
    "作業區分",
    "設置日期",
    "尺寸單位",
    "管徑寬度",
    "管徑高度",
    "涵管條數",
    "管線材料",
    "起點埋設深度",
    "終點埋設深度",
    "管線長度",
    "管線型態",
    "使用狀態",
    "資料狀態",
)

NUMERIC_FIELDS = (
    "管徑寬度",
    "管徑高度",
    "起點埋設深度",
    "終點埋設深度",
    "管線長度",
)


def _local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _quantiles(values: list[float]) -> dict[str, float | int | None]:
    if not values:
        return {"count": 0, "min": None, "p01": None, "median": None, "p99": None, "max": None}
    ordered = sorted(values)

    def at(fraction: float) -> float:
        return ordered[min(len(ordered) - 1, int((len(ordered) - 1) * fraction))]

    return {
        "count": len(ordered),
        "min": ordered[0],
        "p01": at(0.01),
        "median": at(0.5),
        "p99": at(0.99),
        "max": ordered[-1],
    }


def _extract_row(
    element: ET.Element,
) -> tuple[dict[str, str], str | None, str | None, str | None]:
    row: dict[str, str] = {}
    srs_name = None
    srs_dimension = None
    position_list = None
    for child in element.iter():
        name = _local_name(child.tag)
        if name == "LineString":
            srs_name = child.attrib.get("srsName")
            srs_dimension = child.attrib.get("srsDimension")
        elif name == "posList":
            position_list = (child.text or "").strip()
        elif name == "timePosition":
            row["設置日期"] = (child.text or "").strip()
        elif name in TEXT_FIELDS:
            row[name] = (child.text or "").strip()
    return row, srs_name, srs_dimension, position_list


def _planar_length_m(position_list: str | None, dimension: str | None) -> float | None:
    try:
        coordinate_dimension = int(dimension or "")
        values = [float(value) for value in (position_list or "").split()]
    except ValueError:
        return None
    if coordinate_dimension < 2 or len(values) < coordinate_dimension * 2:
        return None
    if len(values) % coordinate_dimension:
        return None
    points = [
        (values[index], values[index + 1])
        for index in range(0, len(values), coordinate_dimension)
    ]
    return sum(
        math.hypot(end_x - start_x, end_y - start_y)
        for (start_x, start_y), (end_x, end_y) in zip(points, points[1:])
    )


def profile_xml(paths: Iterable[Path], as_of_date: date) -> dict[str, object]:
    files: list[dict[str, object]] = []
    value_counts = {field: Counter() for field in TEXT_FIELDS}
    missing_counts = Counter()
    invalid_numeric_counts = Counter()
    zero_counts = Counter()
    numeric_values = {field: [] for field in NUMERIC_FIELDS}
    normalized_diameters_m: list[float] = []
    geometry_lengths_m: list[float] = []
    reported_to_geometry_length_ratios: list[float] = []
    invalid_geometry_position_lists = 0
    reported_length_difference_over_10pct = 0
    segment_ids: set[str] = set()
    duplicate_segment_id_rows = 0
    record_count = 0
    srs_names = Counter()
    srs_dimensions = Counter()
    future_install_date_count = 0

    for path in paths:
        file_record_count = 0
        for _event, element in ET.iterparse(path, events=("end",)):
            if not element.tag.endswith("UTL_管線"):
                continue
            record_count += 1
            file_record_count += 1
            row, srs_name, srs_dimension, position_list = _extract_row(element)
            srs_names[srs_name or "MISSING"] += 1
            srs_dimensions[srs_dimension or "MISSING"] += 1

            segment_id = row.get("識別碼", "")
            if segment_id in segment_ids:
                duplicate_segment_id_rows += 1
            elif segment_id:
                segment_ids.add(segment_id)

            for field in TEXT_FIELDS:
                value = row.get(field, "")
                if value:
                    value_counts[field][value] += 1
                else:
                    missing_counts[field] += 1

            for field in NUMERIC_FIELDS:
                value = row.get(field, "")
                try:
                    number = float(value)
                except (TypeError, ValueError):
                    invalid_numeric_counts[field] += 1
                    continue
                if not math.isfinite(number):
                    invalid_numeric_counts[field] += 1
                    continue
                numeric_values[field].append(number)
                if number == 0:
                    zero_counts[field] += 1

            try:
                unit_multiplier = DIAMETER_UNIT_TO_METRES[row["尺寸單位"]]
                width = float(row["管徑寬度"])
                height = float(row["管徑高度"])
                if width > 0 and height == 0:
                    normalized_diameters_m.append(width * unit_multiplier)
            except (KeyError, TypeError, ValueError):
                pass

            try:
                install_date = date.fromisoformat(row.get("設置日期", ""))
                if install_date > as_of_date:
                    future_install_date_count += 1
            except ValueError:
                pass

            geometry_length_m = _planar_length_m(position_list, srs_dimension)
            if geometry_length_m is None or geometry_length_m <= 0:
                invalid_geometry_position_lists += 1
            else:
                geometry_lengths_m.append(geometry_length_m)
                try:
                    reported_length = float(row["管線長度"])
                    ratio = reported_length / geometry_length_m
                    reported_to_geometry_length_ratios.append(ratio)
                    if ratio < 0.9 or ratio > 1.1:
                        reported_length_difference_over_10pct += 1
                except (KeyError, TypeError, ValueError):
                    pass

            element.clear()

        files.append(
            {
                "path": str(path),
                "sha256": _sha256(path),
                "record_count": file_record_count,
            }
        )

    date_counts = value_counts["設置日期"]
    concentrated_dates = [
        {"date": value, "count": count, "share": count / record_count}
        for value, count in date_counts.most_common()
        if record_count and count / record_count >= 0.05
    ]

    return {
        "profile_kind": "OUTCOME_FREE_SOURCE_DATA_GATE",
        "as_of_date": as_of_date.isoformat(),
        "files": files,
        "record_count": record_count,
        "unique_segment_ids": len(segment_ids),
        "duplicate_segment_id_rows": duplicate_segment_id_rows,
        "srs_name_counts": dict(srs_names),
        "srs_dimension_counts": dict(srs_dimensions),
        "missing_counts": dict(missing_counts),
        "invalid_numeric_counts": dict(invalid_numeric_counts),
        "zero_counts": dict(zero_counts),
        "diameter_unit_code_counts": dict(value_counts["尺寸單位"]),
        "normalized_circular_diameter_m": _quantiles(normalized_diameters_m),
        "start_depth_m": _quantiles(numeric_values["起點埋設深度"]),
        "end_depth_m": _quantiles(numeric_values["終點埋設深度"]),
        "pipe_length_m": _quantiles(numeric_values["管線長度"]),
        "geometry_2d_length_m": _quantiles(geometry_lengths_m),
        "reported_to_geometry_length_ratio": _quantiles(reported_to_geometry_length_ratios),
        "invalid_geometry_position_list_count": invalid_geometry_position_lists,
        "reported_length_difference_over_10pct_count": reported_length_difference_over_10pct,
        "future_install_date_count": future_install_date_count,
        "concentrated_install_dates_at_least_5pct": concentrated_dates,
        "status_value_counts": {
            "作業區分": dict(value_counts["作業區分"]),
            "管線型態": dict(value_counts["管線型態"]),
            "使用狀態": dict(value_counts["使用狀態"]),
            "資料狀態": dict(value_counts["資料狀態"]),
        },
        "model_feature_ready": False,
        "readiness_note": "Source profiling does not satisfy status, depth-outlier, date-concentration, geometry, or coverage gates.",
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("inputs", nargs="+", type=Path)
    parser.add_argument("--as-of-date", required=True, type=date.fromisoformat)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    print(json.dumps(profile_xml(args.inputs, args.as_of_date), ensure_ascii=False, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
