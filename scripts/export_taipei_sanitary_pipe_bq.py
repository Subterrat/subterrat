#!/usr/bin/env python3
"""Export Taipei sanitary-pipe XML as BigQuery-loadable NDJSON.

This exporter is outcome-free. It preserves source values, converts the
official EPSG:3826 line geometry to WGS84 WKT, and records quality flags. It
does not choose model thresholds, rank cells, or read Rat Radar data.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import xml.etree.ElementTree as ET
from datetime import date
from pathlib import Path
from typing import Iterable, TextIO

from pyproj import Transformer

from scripts.profile_taipei_sanitary_pipe_xml import (
    DIAMETER_UNIT_TO_METRES,
    _extract_row,
    _local_name,
    _planar_length_m,
    _sha256,
)


DATASET_ID = "9b25821a-c0d0-438d-a027-4a09f4640813"
SOURCE_CRS = "EPSG:3826"


def _finite_number(value: str | None) -> float | None:
    try:
        number = float(value or "")
    except ValueError:
        return None
    return number if math.isfinite(number) else None


def _iso_date(value: str | None) -> date | None:
    try:
        return date.fromisoformat(value or "")
    except ValueError:
        return None


def _linestring_wkt_wgs84(
    position_list: str | None,
    dimension: str | None,
    source_crs: str | None,
    transformer: Transformer,
) -> str | None:
    if source_crs != SOURCE_CRS:
        return None
    try:
        coordinate_dimension = int(dimension or "")
        values = [float(value) for value in (position_list or "").split()]
    except ValueError:
        return None
    if coordinate_dimension < 2 or len(values) < coordinate_dimension * 2:
        return None
    if len(values) % coordinate_dimension:
        return None

    coordinates: list[str] = []
    for index in range(0, len(values), coordinate_dimension):
        longitude, latitude = transformer.transform(values[index], values[index + 1])
        if not (
            math.isfinite(longitude)
            and math.isfinite(latitude)
            and -180 <= longitude <= 180
            and -90 <= latitude <= 90
        ):
            return None
        coordinates.append(f"{longitude:.9f} {latitude:.9f}")
    return f"LINESTRING ({', '.join(coordinates)})"


def _source_snapshot_id(
    paths: list[Path], resource_ids: list[str], snapshot_date: date
) -> tuple[str, list[dict[str, str]]]:
    files = [
        {
            "file_name": path.name,
            "resource_id": resource_id,
            "sha256": _sha256(path),
        }
        for path, resource_id in zip(paths, resource_ids, strict=True)
    ]
    payload = {
        "dataset_id": DATASET_ID,
        "snapshot_date": snapshot_date.isoformat(),
        "files": files,
    }
    digest = hashlib.sha256(
        json.dumps(payload, ensure_ascii=False, sort_keys=True).encode("utf-8")
    ).hexdigest()
    return digest, files


def export_xml(
    paths: Iterable[Path],
    resource_ids: Iterable[str],
    snapshot_date: date,
    output: TextIO,
) -> dict[str, object]:
    input_paths = list(paths)
    input_resource_ids = list(resource_ids)
    if not input_paths or len(input_paths) != len(input_resource_ids):
        raise ValueError("each XML input requires one resource ID")

    snapshot_id, file_records = _source_snapshot_id(
        input_paths, input_resource_ids, snapshot_date
    )
    transformer = Transformer.from_crs(SOURCE_CRS, "EPSG:4326", always_xy=True)
    segment_ids: set[str] = set()
    record_count = 0
    invalid_geometry_count = 0
    quality_flag_counts: dict[str, int] = {}

    for path, resource_id, file_record in zip(
        input_paths, input_resource_ids, file_records, strict=True
    ):
        for _event, element in ET.iterparse(path, events=("end",)):
            if not element.tag.endswith("UTL_管線"):
                continue

            row, source_crs, source_dimension, position_list = _extract_row(element)
            segment_id = row.get("識別碼", "").strip()
            if not segment_id:
                raise ValueError(f"missing segment ID in {path}")
            if segment_id in segment_ids:
                raise ValueError(f"duplicate segment ID: {segment_id}")
            segment_ids.add(segment_id)

            quality_flags: list[str] = []
            geometry_wkt = _linestring_wkt_wgs84(
                position_list, source_dimension, source_crs, transformer
            )
            if geometry_wkt is None:
                quality_flags.append("INVALID_OR_UNSUPPORTED_GEOMETRY")
                invalid_geometry_count += 1

            geometry_length_m = _planar_length_m(position_list, source_dimension)
            reported_length_m = _finite_number(row.get("管線長度"))
            if geometry_length_m and reported_length_m is not None:
                ratio = reported_length_m / geometry_length_m
                if ratio < 0.9 or ratio > 1.1:
                    quality_flags.append("REPORTED_LENGTH_DIFF_OVER_10PCT")

            width = _finite_number(row.get("管徑寬度"))
            height = _finite_number(row.get("管徑高度"))
            unit_code = row.get("尺寸單位", "")
            unit_multiplier = DIAMETER_UNIT_TO_METRES.get(unit_code)
            circular_diameter_m = None
            if unit_multiplier is None:
                quality_flags.append("UNKNOWN_DIAMETER_UNIT")
            elif width is not None and width > 0 and height == 0:
                circular_diameter_m = width * unit_multiplier
            else:
                quality_flags.append("NON_CIRCULAR_OR_INVALID_DIAMETER")

            start_depth_m = _finite_number(row.get("起點埋設深度"))
            end_depth_m = _finite_number(row.get("終點埋設深度"))
            mean_depth_m = None
            if start_depth_m is not None and end_depth_m is not None:
                mean_depth_m = (start_depth_m + end_depth_m) / 2
            else:
                quality_flags.append("MISSING_OR_INVALID_ENDPOINT_DEPTH")

            install_date = _iso_date(row.get("設置日期"))
            if install_date is None:
                quality_flags.append("MISSING_OR_INVALID_INSTALL_DATE")
            elif install_date > snapshot_date:
                quality_flags.append("INSTALL_DATE_AFTER_SNAPSHOT")

            use_status = row.get("使用狀態", "")
            data_status = row.get("資料狀態", "")
            if use_status != "0":
                quality_flags.append("NOT_ACTIVE")
            if data_status != "0":
                quality_flags.append("NOT_SURVEYED")

            source_payload = {
                "row": row,
                "source_crs": source_crs,
                "source_dimension": source_dimension,
                "position_list": position_list,
            }
            source_row_sha256 = hashlib.sha256(
                json.dumps(
                    source_payload, ensure_ascii=False, sort_keys=True
                ).encode("utf-8")
            ).hexdigest()

            record = {
                "source_snapshot_id": snapshot_id,
                "source_snapshot_date": snapshot_date.isoformat(),
                "source_dataset_id": DATASET_ID,
                "source_resource_id": resource_id,
                "source_file_name": path.name,
                "source_file_sha256": file_record["sha256"],
                "source_row_sha256": source_row_sha256,
                "segment_id": segment_id,
                "start_node_id": row.get("起點編號") or None,
                "end_node_id": row.get("終點編號") or None,
                "source_crs": source_crs,
                "source_dimension": int(source_dimension) if source_dimension else None,
                "geometry_wkt_wgs84": geometry_wkt,
                "geometry_2d_length_m": geometry_length_m,
                "reported_length_m": reported_length_m,
                "diameter_unit_code": unit_code or None,
                "pipe_width_raw": width,
                "pipe_height_raw": height,
                "circular_diameter_m": circular_diameter_m,
                "start_cover_depth_m": start_depth_m,
                "end_cover_depth_m": end_depth_m,
                "mean_cover_depth_m": mean_depth_m,
                "install_date": install_date.isoformat() if install_date else None,
                "pipe_material": row.get("管線材料") or None,
                "operation_type_code": row.get("作業區分") or None,
                "pipe_type_code": row.get("管線型態") or None,
                "use_status_code": use_status or None,
                "data_status_code": data_status or None,
                "is_active": use_status == "0",
                "is_surveyed": data_status == "0",
                "quality_flags": sorted(quality_flags),
            }
            output.write(json.dumps(record, ensure_ascii=False, sort_keys=True) + "\n")
            record_count += 1
            for flag in quality_flags:
                quality_flag_counts[flag] = quality_flag_counts.get(flag, 0) + 1
            element.clear()

    return {
        "manifest_kind": "TAIPEI_SANITARY_PIPE_BIGQUERY_EXPORT_V0_2",
        "source_snapshot_id": snapshot_id,
        "source_snapshot_date": snapshot_date.isoformat(),
        "source_dataset_id": DATASET_ID,
        "files": file_records,
        "record_count": record_count,
        "unique_segment_ids": len(segment_ids),
        "invalid_geometry_count": invalid_geometry_count,
        "quality_flag_counts": dict(sorted(quality_flag_counts.items())),
        "outcome_data_read": False,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("inputs", nargs="+", type=Path)
    parser.add_argument("--resource-id", action="append", required=True)
    parser.add_argument("--snapshot-date", required=True, type=date.fromisoformat)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--manifest", required=True, type=Path)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.manifest.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8") as output:
        manifest = export_xml(
            args.inputs,
            args.resource_id,
            args.snapshot_date,
            output,
        )
    manifest["ndjson_sha256"] = _sha256(args.output)
    args.manifest.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
