from __future__ import annotations

from datetime import date, datetime
from typing import Any

from services.hotspot_api.bigquery_gateway import BigQueryGateway
from services.hotspot_api.schemas.lab_v03 import (
    V03EvaluationSummaryResponse,
    V03EvaluationSummaryRow,
)


_COLUMNS = (
    "ecological_tolerance_m",
    "tolerance_role",
    "report_denominator",
    "v0_3_overlapping_report_count",
    "v0_3_report_overlap_fraction",
    "v0_3_buffered_taipei_area_share",
    "v0_3_report_overlap_to_area_ratio",
    "food_overlapping_report_count",
    "food_report_overlap_fraction",
    "food_buffered_taipei_area_share",
    "food_report_overlap_to_area_ratio",
    "difference_in_report_overlap_vs_food_v0_1",
    "distance_semantics",
    "footprint_semantics",
    "calculation_path",
    "evaluation_kind",
    "outcome_role",
    "evaluated_variant_id",
    "baseline_variant_id",
    "specification_git_head",
    "source_csv_sha256",
    "observed_from",
    "observed_to",
    "score_semantics",
    "evidence_state",
    "use_state",
    "operational_use",
    "public_release_ready",
    "literature_doi",
    "literature_interpretation",
    "limitation_codes",
)
_SELECT_LIST = ", ".join(_COLUMNS)
_ALLOWED_TOLERANCES = (0, 200)
_SCORE_SEMANTICS = "REPORT_OVERLAP_FRACTION_NOT_PROBABILITY_OR_ACCURACY"


def _isoformat(value: Any) -> str:
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    return str(value)


def _row_to_schema(row: dict[str, Any]) -> V03EvaluationSummaryRow:
    return V03EvaluationSummaryRow(
        ecological_tolerance_m=int(row["ecological_tolerance_m"]),
        tolerance_role=row["tolerance_role"],
        report_denominator=int(row["report_denominator"]),
        v0_3_overlapping_report_count=int(row["v0_3_overlapping_report_count"]),
        v0_3_report_overlap_fraction=float(row["v0_3_report_overlap_fraction"]),
        v0_3_buffered_taipei_area_share=float(
            row["v0_3_buffered_taipei_area_share"]
        ),
        v0_3_report_overlap_to_area_ratio=float(
            row["v0_3_report_overlap_to_area_ratio"]
        ),
        food_overlapping_report_count=int(row["food_overlapping_report_count"]),
        food_report_overlap_fraction=float(row["food_report_overlap_fraction"]),
        food_buffered_taipei_area_share=float(
            row["food_buffered_taipei_area_share"]
        ),
        food_report_overlap_to_area_ratio=float(
            row["food_report_overlap_to_area_ratio"]
        ),
        difference_in_report_overlap_vs_food_v0_1=float(
            row["difference_in_report_overlap_vs_food_v0_1"]
        ),
        distance_semantics=row["distance_semantics"],
        footprint_semantics=row["footprint_semantics"],
        calculation_path=row["calculation_path"],
        evaluation_kind=row["evaluation_kind"],
        outcome_role=row["outcome_role"],
        evaluated_variant_id=row["evaluated_variant_id"],
        baseline_variant_id=row["baseline_variant_id"],
        specification_git_head=row["specification_git_head"],
        source_csv_sha256=row["source_csv_sha256"],
        observed_from=_isoformat(row["observed_from"]),
        observed_to=_isoformat(row["observed_to"]),
        score_semantics=row["score_semantics"],
        evidence_state=row["evidence_state"],
        use_state=row["use_state"],
        operational_use=row["operational_use"],
        public_release_ready=bool(row["public_release_ready"]),
        literature_doi=row["literature_doi"],
        literature_interpretation=row["literature_interpretation"],
        limitation_codes=list(row.get("limitation_codes") or []),
    )


class V03EvaluationRepository:
    def __init__(self, gateway: BigQueryGateway, table_ref: str) -> None:
        self._gateway = gateway
        self._table_ref = table_ref

    def get_summary(self) -> V03EvaluationSummaryResponse:
        sql = f"""
        SELECT {_SELECT_LIST}
        FROM `{self._table_ref}`
        WHERE ecological_tolerance_m IN (0, 200)
          AND score_semantics = '{_SCORE_SEMANTICS}'
          AND evidence_state = 'NO_TRUSTED_RESULT'
          AND use_state = 'INTERNAL_RESEARCH_ONLY'
          AND operational_use = 'PROHIBITED'
          AND NOT public_release_ready
        ORDER BY ecological_tolerance_m
        """
        rows = self._gateway.query(sql)
        tolerances = [int(row["ecological_tolerance_m"]) for row in rows]
        if len(rows) != 2 or tolerances != list(_ALLOWED_TOLERANCES):
            raise ValueError(
                "v0.3 evaluation summary must contain exactly the 0m and 200m rows"
            )
        result_rows = [_row_to_schema(row) for row in rows]
        return V03EvaluationSummaryResponse(rows=result_rows)
