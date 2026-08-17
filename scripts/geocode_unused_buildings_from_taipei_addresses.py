#!/usr/bin/env python3
"""Join unused-building addresses to Taipei's official address-point CSV.

The output is an address-point candidate layer. It is not a building centroid,
parcel location, or proof that the source represents citywide abandonment.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import unicodedata
from collections import defaultdict
from pathlib import Path

from pyproj import Transformer


DISTRICT_CODES = {
    "松山區": "63000010",
    "信義區": "63000020",
    "大安區": "63000030",
    "中山區": "63000040",
    "中正區": "63000050",
    "大同區": "63000060",
    "萬華區": "63000070",
    "文山區": "63000080",
    "南港區": "63000090",
    "內湖區": "63000100",
    "士林區": "63000110",
    "北投區": "63000120",
}

DIGIT_TO_CHINESE = {
    "1": "一",
    "2": "二",
    "3": "三",
    "4": "四",
    "5": "五",
    "6": "六",
    "7": "七",
    "8": "八",
    "9": "九",
}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def normalize_address(value: str) -> str:
    normalized = unicodedata.normalize("NFKC", value or "")
    normalized = normalized.replace("台", "臺")
    normalized = re.sub(r"[\s　]", "", normalized)
    normalized = re.sub(r"[（(].*$", "", normalized)
    normalized = re.sub(r"(?<=\d)[‐‑‒–—－-](?=\d)", "之", normalized)

    def section_replacement(match: re.Match[str]) -> str:
        return f"{match.group(1)}{DIGIT_TO_CHINESE[match.group(2)]}段"

    normalized = re.sub(r"([路街道])([1-9])段", section_replacement, normalized)
    number_end = normalized.find("號")
    if number_end >= 0:
        normalized = normalized[: number_end + 1]
    return normalized


def load_buildings(path: Path) -> list[dict[str, str]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    rows = payload["result"]["results"]
    buildings = []
    for row in rows:
        district = row["行政區"]
        if district not in DISTRICT_CODES:
            raise ValueError(f"Unknown Taipei district: {district}")
        buildings.append(
            {
                "source_building_id": str(row["序號"]),
                "district": district,
                "district_code": DISTRICT_CODES[district],
                "source_address": row["門牌"],
                "address_key": normalize_address(row["門牌"]),
                "building_label": row["建物標示"],
            }
        )
    return buildings


def join_address_points(
    buildings: list[dict[str, str]], address_csv: Path
) -> list[dict[str, object]]:
    targets = {
        (building["district_code"], building["address_key"])
        for building in buildings
    }
    matched_rows: dict[tuple[str, str], list[tuple[float, float]]] = defaultdict(list)

    with address_csv.open("r", encoding="utf-8-sig", newline="") as source:
        reader = csv.DictReader(source)
        expected = {
            "鄉鎮市區代碼",
            "街路段",
            "地區",
            "巷",
            "弄",
            "號",
            "橫座標",
            "縱座標",
        }
        missing = expected.difference(reader.fieldnames or [])
        if missing:
            raise ValueError(f"Address CSV missing columns: {sorted(missing)}")

        for row in reader:
            district_code = row["鄉鎮市區代碼"]
            if district_code not in DISTRICT_CODES.values():
                continue
            address_key = normalize_address(
                "".join(
                    row.get(field, "")
                    for field in ("街路段", "地區", "巷", "弄", "號")
                )
            )
            target = (district_code, address_key)
            if target not in targets:
                continue
            try:
                coordinate = (float(row["橫座標"]), float(row["縱座標"]))
            except (TypeError, ValueError):
                continue
            matched_rows[target].append(coordinate)

    transformer = Transformer.from_crs("EPSG:3826", "EPSG:4326", always_xy=True)
    output = []
    for building in buildings:
        target = (building["district_code"], building["address_key"])
        rows = matched_rows.get(target, [])
        coordinates = sorted(set(rows))
        selected = coordinates[0] if len(coordinates) == 1 else None
        if selected:
            longitude, latitude = transformer.transform(*selected)
            status = "MATCHED_EXACT_ADDRESS_POINT_REVIEW_REQUIRED"
            method = "OFFICIAL_ADDRESS_CSV_EXACT_DISTRICT_ADDRESS"
        elif coordinates:
            longitude = latitude = None
            status = "BLOCKED_MULTIPLE_COORDINATES"
            method = "OFFICIAL_ADDRESS_CSV_AMBIGUOUS"
        else:
            longitude = latitude = None
            status = "BLOCKED_NO_EXACT_ADDRESS_MATCH"
            method = "NO_MATCH"
        output.append(
            {
                **building,
                "matched_source_rows": len(rows),
                "unique_coordinate_count": len(coordinates),
                "twd97_x": selected[0] if selected else None,
                "twd97_y": selected[1] if selected else None,
                "longitude": longitude,
                "latitude": latitude,
                "match_method": method,
                "location_status": status,
            }
        )
    return output


def write_csv(rows: list[dict[str, object]], output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = list(rows[0])
    with output_path.open("w", encoding="utf-8", newline="") as target:
        writer = csv.DictWriter(target, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--buildings-json", type=Path, required=True)
    parser.add_argument("--address-csv", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    buildings = load_buildings(args.buildings_json)
    rows = join_address_points(buildings, args.address_csv)
    building_source_sha256 = sha256_file(args.buildings_json)
    address_source_sha256 = sha256_file(args.address_csv)
    for row in rows:
        row["building_source_sha256"] = building_source_sha256
        row["address_source_sha256"] = address_source_sha256
        row["address_source_crs"] = "EPSG:3826"
        row["output_crs"] = "EPSG:4326"
        row["source_license"] = "Taiwan Government Data Open License 1.0"
    write_csv(rows, args.output)

    matched = sum(row["longitude"] is not None for row in rows)
    ambiguous = sum(row["location_status"] == "BLOCKED_MULTIPLE_COORDINATES" for row in rows)
    print(
        json.dumps(
            {
                "total": len(rows),
                "matched": matched,
                "ambiguous": ambiguous,
                "unmatched": len(rows) - matched - ambiguous,
                "output": str(args.output),
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()
