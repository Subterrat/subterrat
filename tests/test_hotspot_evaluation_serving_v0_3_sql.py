import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SQL_PATH = (
    ROOT
    / "sql"
    / "validation"
    / "24_materialize_hotspot_evaluation_serving_v0_3.sql"
)


class HotspotEvaluationServingV03SqlTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.sql = SQL_PATH.read_text(encoding="utf-8")

    def test_materializes_two_fixed_aggregate_radii(self) -> None:
        self.assertIn(
            "hotspot_evaluation_summary_v0_3_internal_simulation", self.sql
        )
        self.assertIn("0 AS ecological_tolerance_m", self.sql)
        self.assertIn("tolerance.ecological_tolerance_m", self.sql)
        self.assertIn("COUNT(*) = 2", self.sql)
        self.assertIn("COUNTIF(ecological_tolerance_m = 0) = 1", self.sql)
        self.assertIn("COUNTIF(ecological_tolerance_m = 200) = 1", self.sql)

    def test_keeps_composite_and_food_metrics_on_each_row(self) -> None:
        for column in (
            "v0_3_overlapping_report_count",
            "v0_3_report_overlap_fraction",
            "v0_3_buffered_taipei_area_share",
            "v0_3_report_overlap_to_area_ratio",
            "food_overlapping_report_count",
            "food_report_overlap_fraction",
            "food_buffered_taipei_area_share",
            "food_report_overlap_to_area_ratio",
            "difference_in_report_overlap_vs_food_v0_1",
        ):
            self.assertIn(column, self.sql)

    def test_fail_closed_inputs_and_outputs_are_asserted(self) -> None:
        self.assertIn("COUNT(*) = 1", self.sql)
        self.assertIn("COUNTIF(report_denominator IS DISTINCT FROM 889) = 0", self.sql)
        self.assertIn(
            "b5f9f5223aa514bc3b02159f974efbb72e5cb75333384dde8a98f281305aa37a",
            self.sql,
        )
        self.assertIn("NO_TRUSTED_RESULT", self.sql)
        self.assertIn("INTERNAL_RESEARCH_ONLY", self.sql)
        self.assertIn("PROHIBITED", self.sql)
        self.assertIn(
            "COUNTIF(public_release_ready IS DISTINCT FROM FALSE) = 0",
            self.sql,
        )
        self.assertIn("does not reproduce the primary aggregate", self.sql)
        self.assertIn("does not reproduce the source aggregate", self.sql)

    def test_provenance_window_literature_and_limitations_are_served(self) -> None:
        for column in (
            "specification_git_head",
            "source_csv_sha256",
            "observed_from",
            "observed_to",
            "score_semantics",
            "literature_doi",
            "literature_interpretation",
            "limitation_codes",
            "source_table",
        ):
            self.assertIn(column, self.sql)
        self.assertIn("10.1071/WR11149", self.sql)
        self.assertIn(
            "REPORT_OVERLAP_FRACTION_NOT_PROBABILITY_OR_ACCURACY", self.sql
        )

    def test_output_does_not_expose_row_level_or_spatial_fields(self) -> None:
        serving_projection = self.sql.split("serving_rows AS (", 1)[1]
        for forbidden in (
            " as report_id",
            " as cell_id",
            " as latitude",
            " as longitude",
            " as geography",
            " as probability",
            " as calibrated_probability",
        ):
            self.assertNotIn(forbidden, serving_projection.lower())
        self.assertNotIn("CREATE MODEL", self.sql.upper())


if __name__ == "__main__":
    unittest.main()
