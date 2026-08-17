#!/usr/bin/env python3
"""Build a versioned Taipei S2 grid from an authoritative boundary snapshot.

The output contains no Rat Radar data. It is an immutable input candidate for
BigQuery `subterrat_raw.taipei_s2_l15_grid_raw`.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import tempfile
import urllib.request
import zipfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

import shapefile
from pyproj import Geod, Transformer
from s2sphere import Cell, CellId, LatLng, LatLngRect, RegionCoverer
from shapely.geometry import Polygon, mapping, shape
from shapely.ops import transform, unary_union


DEFAULT_BOUNDARY_URL = (
    "https://www.tgos.tw/tgos/VirtualDir/Product/"
    "1cd4f4c9-6b01-4cf9-bf6c-23a73aa17d24/"
    "%E7%9B%B4%E8%BD%84%E5%B8%82%E3%80%81%E7%B8%A3%28%E5%B8%82%29"
    "%E7%95%8C%E7%B7%9A1140318.zip"
)
BOUNDARY_DATASET_URL = "https://data.gov.tw/dataset/7442"
BOUNDARY_VERSION = "COUNTY_MOI_1140318"
GRID_VERSION = "taipei_county_1140318_s2_l15_v1"
TARGET_COUNTY_NAME = "臺北市"


def sha256_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def to_signed_int64(value: int) -> int:
    if value >= 1 << 63:
        return value - (1 << 64)
    return value


def download(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": "SubTerrat/0.1"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read()


def extract_boundary(zip_bytes: bytes, destination: Path) -> Path:
    archive_path = destination / "boundary.zip"
    archive_path.write_bytes(zip_bytes)
    with zipfile.ZipFile(archive_path) as archive:
        archive.extractall(destination)
    shapefiles = sorted(destination.glob("*.shp"))
    if len(shapefiles) != 1:
        raise ValueError(f"expected exactly one shapefile, found {len(shapefiles)}")
    return shapefiles[0]


def read_taipei_boundary(shapefile_path: Path):
    reader = shapefile.Reader(str(shapefile_path), encoding="utf-8")
    field_names = [field[0] for field in reader.fields[1:]]
    county_key = next(
        (name for name in field_names if name.upper() in {"COUNTYNAME", "COUNTY_NAM"}),
        None,
    )
    if county_key is None:
        raise ValueError(f"county-name field not found in {field_names}")

    source_parts = []
    for shape_record in reader.iterShapeRecords():
        attributes = dict(zip(field_names, shape_record.record))
        if str(attributes.get(county_key, "")).strip() == TARGET_COUNTY_NAME:
            source_parts.append(shape(shape_record.shape.__geo_interface__))
    if not source_parts:
        raise ValueError(f"{TARGET_COUNTY_NAME} boundary not found")

    # The official resource is TWD97 geographic. Transform explicitly to WGS84
    # and preserve the source snapshot rather than treating coordinates as equal.
    transformer = Transformer.from_crs("EPSG:3824", "EPSG:4326", always_xy=True)
    boundary = transform(transformer.transform, unary_union(source_parts))
    if boundary.is_empty or not boundary.is_valid:
        raise ValueError("Taipei boundary is empty or invalid after transformation")
    return boundary


def cell_polygon(cell_id: CellId) -> Polygon:
    cell = Cell(cell_id)
    vertices = []
    for index in range(4):
        lat_lng = LatLng.from_point(cell.get_vertex(index))
        vertices.append((lat_lng.lng().degrees, lat_lng.lat().degrees))
    vertices.append(vertices[0])
    return Polygon(vertices)


def covering_cells(boundary, level: int) -> Iterable[CellId]:
    min_x, min_y, max_x, max_y = boundary.bounds
    rectangle = LatLngRect.from_point_pair(
        LatLng.from_degrees(min_y, min_x),
        LatLng.from_degrees(max_y, max_x),
    )
    coverer = RegionCoverer()
    coverer.min_level = level
    coverer.max_level = level
    coverer.max_cells = 1_000_000
    return sorted(coverer.get_covering(rectangle), key=lambda item: item.id())


def build_rows(boundary, level: int, source_sha256: str):
    geod = Geod(ellps="GRS80")
    for s2_cell_id in covering_cells(boundary, level):
        full_polygon = cell_polygon(s2_cell_id)
        clipped_polygon = full_polygon.intersection(boundary)
        if clipped_polygon.is_empty:
            continue
        eligible_area_m2 = abs(geod.geometry_area_perimeter(clipped_polygon)[0])
        if eligible_area_m2 <= 0:
            continue
        centroid = clipped_polygon.centroid
        yield {
            "grid_version": GRID_VERSION,
            "boundary_version": BOUNDARY_VERSION,
            "boundary_dataset_uri": BOUNDARY_DATASET_URL,
            "boundary_resource_uri": DEFAULT_BOUNDARY_URL,
            "boundary_sha256": source_sha256,
            "s2_level": level,
            "cell_id": to_signed_int64(s2_cell_id.id()),
            "cell_token": s2_cell_id.to_token(),
            "centroid_longitude": centroid.x,
            "centroid_latitude": centroid.y,
            "full_geojson": json.dumps(mapping(full_polygon), separators=(",", ":")),
            "clipped_geojson": json.dumps(
                mapping(clipped_polygon), separators=(",", ":")
            ),
            "eligible_area_m2": eligible_area_m2,
        }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--boundary-url", default=DEFAULT_BOUNDARY_URL)
    parser.add_argument("--level", type=int, default=15)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.level != 15:
        raise ValueError("v0.1 contract requires S2 Level 15")

    zip_bytes = download(args.boundary_url)
    source_sha256 = sha256_bytes(zip_bytes)
    with tempfile.TemporaryDirectory(prefix="subterrat-boundary-") as temp_dir:
        shapefile_path = extract_boundary(zip_bytes, Path(temp_dir))
        boundary = read_taipei_boundary(shapefile_path)
        rows = list(build_rows(boundary, args.level, source_sha256))

    if not rows:
        raise ValueError("grid generation returned zero cells")
    if len({row["cell_id"] for row in rows}) != len(rows):
        raise ValueError("grid generation returned duplicate S2 cell IDs")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8") as handle:
        for row in rows:
            handle.write(json.dumps(row, ensure_ascii=False, separators=(",", ":")))
            handle.write("\n")

    output_sha256 = hashlib.sha256(args.output.read_bytes()).hexdigest()
    manifest = {
        "artifact": str(args.output),
        "artifact_sha256": output_sha256,
        "boundary_dataset_uri": BOUNDARY_DATASET_URL,
        "boundary_resource_uri": args.boundary_url,
        "boundary_sha256": source_sha256,
        "boundary_version": BOUNDARY_VERSION,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "grid_version": GRID_VERSION,
        "row_count": len(rows),
        "s2_level": args.level,
        "total_eligible_area_m2": sum(row["eligible_area_m2"] for row in rows),
    }
    args.manifest.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(manifest, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
