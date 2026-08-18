#!/usr/bin/env python3
"""Export the repository urban-renewal CSV as outcome-free BigQuery NDJSON.

File and canonical-row hashes preserve source identity. Only the fields needed
for phase QA and spatial aggregation are exported; project names, location text,
and full source payloads remain local. The exporter does not read Rat Radar,
calculate a hotspot score, or infer actual construction dates.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
from collections import Counter
from datetime import date
from pathlib import Path
from typing import TextIO


PRIMARY_LAYER_PREFIX = "已核定重建更新事業-"
PRIMARY_STATUSES = {
    "已核定",
    "施工",
    "施工中",
    "核定",
    "權利變換審查",
    "權變審議",
    "權變核定",
}
COMPLETED_STATUSES = {"完工", "已完工"}


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _canonical_row(row: dict[str, str]) -> str:
    return json.dumps(row, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def _finite_float(value: str | None) -> float | None:
    try:
        number = float((value or "").strip())
    except ValueError:
        return None
    return number if math.isfinite(number) else None


def _phase_group(layer: str, status: str) -> str:
    if layer.startswith(PRIMARY_LAYER_PREFIX):
        if status in COMPLETED_STATUSES:
            return "COMPLETED"
        if status in PRIMARY_STATUSES:
            return "APPROVED_NON_COMPLETE_PROXY"
        return "APPROVED_PROJECT_UNKNOWN_STATUS"
    if layer == "中央及市府主導":
        return "GOVERNMENT_LED_UNKNOWN_PHASE"
    return "PLANNING_OR_DESIGNATION"


def export_csv(
    path: Path,
    snapshot_date: date,
    source_uri: str,
    output: TextIO,
) -> dict[str, object]:
    file_sha256 = _sha256(path)
    snapshot_payload = {
        "file_name": path.name,
        "file_sha256": file_sha256,
        "snapshot_date": snapshot_date.isoformat(),
        "source_uri": source_uri,
    }
    source_snapshot_id = hashlib.sha256(
        json.dumps(snapshot_payload, ensure_ascii=False, sort_keys=True).encode("utf-8")
    ).hexdigest()

    with path.open("r", encoding="utf-8-sig", newline="") as source:
        reader = csv.DictReader(source)
        rows = list(reader)
        fieldnames = reader.fieldnames or []

    required_fields = {"圖層", "目前狀態", "經度", "緯度"}
    missing_fields = required_fields.difference(fieldnames)
    if missing_fields:
        raise ValueError(f"missing required CSV fields: {sorted(missing_fields)}")

    canonical_rows = [_canonical_row(row) for row in rows]
    row_hashes = [hashlib.sha256(row.encode("utf-8")).hexdigest() for row in canonical_rows]
    if len(row_hashes) != len(set(row_hashes)):
        raise ValueError("exact duplicate source rows are not allowed")

    coordinate_counts: Counter[tuple[float, float]] = Counter()
    parsed_coordinates: list[tuple[float | None, float | None]] = []
    for row in rows:
        longitude = _finite_float(row.get("經度"))
        latitude = _finite_float(row.get("緯度"))
        parsed_coordinates.append((longitude, latitude))
        if longitude is not None and latitude is not None:
            coordinate_counts[(longitude, latitude)] += 1

    phase_group_counts: Counter[str] = Counter()
    quality_flag_counts: Counter[str] = Counter()
    primary_included_rows = 0

    for source_row_number, (row, canonical, row_hash, coordinates) in enumerate(
        zip(rows, canonical_rows, row_hashes, parsed_coordinates), start=2
    ):
        layer = (row.get("圖層") or "").strip()
        status = (row.get("目前狀態") or "").strip()
        longitude, latitude = coordinates
        phase_group = _phase_group(layer, status)
        phase_group_counts[phase_group] += 1
        primary_included = phase_group == "APPROVED_NON_COMPLETE_PROXY"
        primary_included_rows += int(primary_included)

        quality_flags: list[str] = []
        if longitude is None or latitude is None:
            quality_flags.append("MISSING_OR_INVALID_COORDINATE")
        elif not (121.3 <= longitude <= 121.8 and 24.8 <= latitude <= 25.3):
            quality_flags.append("COORDINATE_OUTSIDE_TAIPEI_REVIEW_BOX")
        elif coordinate_counts[(longitude, latitude)] > 1:
            quality_flags.append("DUPLICATE_EXACT_COORDINATE")
        if phase_group == "APPROVED_PROJECT_UNKNOWN_STATUS":
            quality_flags.append("APPROVED_PROJECT_STATUS_MISSING_OR_UNKNOWN")
        if phase_group == "GOVERNMENT_LED_UNKNOWN_PHASE":
            quality_flags.append("GOVERNMENT_LED_PHASE_UNKNOWN")
        if phase_group == "PLANNING_OR_DESIGNATION":
            quality_flags.append("NOT_AN_APPROVED_PROJECT_PHASE")

        for flag in quality_flags:
            quality_flag_counts[flag] += 1

        record = {
            "source_snapshot_id": source_snapshot_id,
            "source_snapshot_date": snapshot_date.isoformat(),
            "source_uri": source_uri,
            "source_file_name": path.name,
            "source_file_sha256": file_sha256,
            "source_row_number": source_row_number,
            "source_row_sha256": row_hash,
            "renewal_record_id": row_hash,
            "layer_name": layer,
            "record_number": (row.get("編號") or "").strip() or None,
            "district": (row.get("行政區") or "").strip() or None,
            "current_status": status or None,
            "approval_date_raw": (row.get("核准日期") or "").strip() or None,
            "business_plan_approval_date_raw": (
                row.get("事業計畫核定日期") or ""
            ).strip()
            or None,
            "announcement_date_raw": (row.get("公告日期") or "").strip() or None,
            "completion_year_raw": (row.get("完工年度") or "").strip() or None,
            "longitude": longitude,
            "latitude": latitude,
            "phase_group": phase_group,
            "primary_scenario_included": primary_included,
            "quality_flags": sorted(quality_flags),
        }
        output.write(json.dumps(record, ensure_ascii=False, sort_keys=True) + "\n")

    return {
        "manifest_kind": "TAIPEI_URBAN_RENEWAL_BIGQUERY_EXPORT_V0_3",
        "source_snapshot_id": source_snapshot_id,
        "source_snapshot_date": snapshot_date.isoformat(),
        "snapshot_date_semantics": (
            "REPOSITORY_OBSERVED_DATE_NOT_PROVIDER_PUBLICATION_DATE"
        ),
        "source_uri": source_uri,
        "source_file_name": path.name,
        "source_file_sha256": file_sha256,
        "record_count": len(rows),
        "unique_source_row_sha256": len(set(row_hashes)),
        "unique_exact_coordinates": len(coordinate_counts),
        "coordinate_duplicate_excess_rows": sum(
            count - 1 for count in coordinate_counts.values() if count > 1
        ),
        "coordinate_rows_in_duplicate_groups": sum(
            count for count in coordinate_counts.values() if count > 1
        ),
        "primary_scenario_included_rows": primary_included_rows,
        "phase_group_counts": dict(sorted(phase_group_counts.items())),
        "quality_flag_counts": dict(sorted(quality_flag_counts.items())),
        "source_lineage_state": (
            "BLOCKED_SOURCE_OWNER_LICENSE_SNAPSHOT_AND_COMPLETENESS_UNDOCUMENTED"
        ),
        "outcome_data_read": False,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("--snapshot-date", required=True, type=date.fromisoformat)
    parser.add_argument("--source-uri", required=True)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--manifest", required=True, type=Path)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.manifest.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8") as output:
        manifest = export_csv(
            args.input,
            args.snapshot_date,
            args.source_uri,
            output,
        )
    manifest["ndjson_sha256"] = _sha256(args.output)
    args.manifest.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
