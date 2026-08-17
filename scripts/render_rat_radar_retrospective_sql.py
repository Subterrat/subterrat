#!/usr/bin/env python3
"""Render validation-only BigQuery SQL from a transient Rat Radar CSV.

The generated SQL embeds only row hashes and S2 cell IDs. Raw descriptions,
photos, coordinates, and addresses are not persisted in BigQuery.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
from datetime import datetime
from pathlib import Path

from s2sphere import CellId, LatLng


APPROVED_STATUSES = {"已審核", "已通報1999"}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_outcomes(path: Path) -> tuple[list[tuple[str, int]], str, str]:
    outcomes: dict[str, int] = {}
    timestamps: list[datetime] = []
    with path.open("r", encoding="utf-8-sig", newline="") as source:
        for row in csv.DictReader(source):
            if row["類型"] != "鼠蹤":
                continue
            if row["狀態"] not in APPROVED_STATUSES:
                continue
            if not row["地點"].startswith("臺北市"):
                continue
            try:
                latitude = float(row["緯度"])
                longitude = float(row["經度"])
                timestamp = datetime.strptime(row["通報時間"], "%Y-%m-%d %H:%M")
            except (TypeError, ValueError):
                continue
            canonical = json.dumps(row, ensure_ascii=False, sort_keys=True)
            report_id = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
            cell_id = (
                CellId.from_lat_lng(LatLng.from_degrees(latitude, longitude))
                .parent(15)
                .id()
            )
            outcomes[report_id] = cell_id
            timestamps.append(timestamp)
    if not outcomes:
        raise ValueError("No approved Taipei rat reports found")
    return sorted(outcomes.items()), min(timestamps).isoformat(), max(timestamps).isoformat()


def render_sql(csv_path: Path) -> str:
    outcomes, observed_from, observed_to = load_outcomes(csv_path)
    source_sha256 = sha256_file(csv_path)
    structs = ",\n    ".join(
        f"STRUCT('{report_id}' AS report_id, CAST({cell_id} AS INT64) AS cell_id)"
        for report_id, cell_id in outcomes
    )
    denominator = len(outcomes)
    return f"""-- Generated validation-only SQL. No raw Rat Radar row is persisted.
ASSERT (
  SELECT COUNTIF(freeze_status = 'T0_LAYERWISE_FROZEN_AWAITING_VALIDATION') = 1
  FROM `devjam26aug17tpe-1270.subterrat_predictions.freeze_manifest`
) AS 'Retrospective validation is forbidden before T0 freeze';

CREATE SCHEMA IF NOT EXISTS
  `devjam26aug17tpe-1270.subterrat_evaluation`
OPTIONS(location = 'asia-east1');

CREATE OR REPLACE TABLE
  `devjam26aug17tpe-1270.subterrat_evaluation.rat_radar_layer_retrospective_v0_1` AS
WITH
outcome AS (
  SELECT * FROM UNNEST([
    {structs}
  ])
),
frozen AS (
  SELECT *
  FROM `devjam26aug17tpe-1270.subterrat_predictions.layer_scores_t0`
),
variant_area AS (
  SELECT
    variant_id,
    SAFE_DIVIDE(
      SUM(IF(top_10pct_area_flag, eligible_area_m2, 0)),
      SUM(eligible_area_m2)
    ) AS selected_area_share
  FROM frozen
  GROUP BY variant_id
),
coverage AS (
  SELECT COUNT(DISTINCT outcome.report_id) AS matched_grid_reports
  FROM outcome
  JOIN (SELECT DISTINCT cell_id FROM frozen) USING (cell_id)
),
captured AS (
  SELECT
    frozen.variant_id,
    COUNT(DISTINCT IF(
      frozen.top_10pct_area_flag,
      outcome.report_id,
      NULL
    )) AS numerator,
    COUNT(DISTINCT IF(
      frozen.layer_score IS NULL,
      outcome.report_id,
      NULL
    )) AS unscored_outcome_reports
  FROM frozen
  LEFT JOIN outcome USING (cell_id)
  GROUP BY frozen.variant_id
)
SELECT
  captured.variant_id,
  {denominator} AS denominator,
  coverage.matched_grid_reports,
  {denominator} - coverage.matched_grid_reports AS unmatched_grid_reports,
  captured.unscored_outcome_reports,
  captured.numerator,
  variant_area.selected_area_share,
  SAFE_DIVIDE(captured.numerator, {denominator}) AS capture,
  SAFE_DIVIDE(
    SAFE_DIVIDE(captured.numerator, {denominator}),
    variant_area.selected_area_share
  ) AS lift_over_area,
  'DEVELOPMENT_EXPOSED_RETROSPECTIVE' AS evaluation_kind,
  'VALIDATION_ONLY_NOT_TRAINING' AS outcome_role,
  '{source_sha256}' AS source_csv_sha256,
  TIMESTAMP('{observed_from}') AS observed_from,
  TIMESTAMP('{observed_to}') AS observed_to
FROM captured
JOIN variant_area USING (variant_id)
CROSS JOIN coverage;

ASSERT (
  SELECT COUNT(*) = 2 AND COUNTIF(denominator != {denominator}) = 0
  FROM `devjam26aug17tpe-1270.subterrat_evaluation.rat_radar_layer_retrospective_v0_1`
) AS 'Retrospective evaluation variant or denominator mismatch';
"""


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("csv", type=Path)
    args = parser.parse_args()
    print(render_sql(args.csv))


if __name__ == "__main__":
    main()
