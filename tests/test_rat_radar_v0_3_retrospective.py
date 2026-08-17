import tempfile
import unittest
from pathlib import Path

from scripts.render_rat_radar_v0_3_retrospective_sql import render_sql


class RatRadarV03RetrospectiveTest(unittest.TestCase):
    def test_renderer_is_lock_gated_anonymous_and_non_selecting(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            csv_path = Path(directory) / "reports.csv"
            csv_path.write_text(
                "通報時間,類型,地點,狀態,說明,照片網址,緯度,經度\n"
                "2026-05-01 10:00,鼠蹤,臺北市 大安區,已審核,secret,,25.03,121.54\n"
                "2026-05-01 11:00,鼠蹤,新北市 板橋區,已審核,excluded,,25.01,121.46\n"
                "2026-05-01 12:00,毒餌,臺北市 大安區,已審核,excluded,,25.03,121.54\n",
                encoding="utf-8",
            )
            sql = render_sql(csv_path)

        self.assertIn(
            "LOCKED_AWAITING_ONE_SHOT_RETROSPECTIVE_CONCORDANCE", sql
        )
        self.assertIn("1 AS report_denominator", sql)
        self.assertIn("report_overlap_fraction", sql)
        self.assertIn("report_overlap_to_area_ratio", sql)
        self.assertIn("difference_in_report_overlap_vs_food_v0_1", sql)
        self.assertIn("unscored_report_fraction", sql)
        self.assertIn("PRIMARY_CITYWIDE_MAP_AS_DELIVERED", sql)
        self.assertIn("SECONDARY_EXACT_V0_3_COMMON_SUPPORT", sql)
        self.assertIn("COUNT(*) = 1", sql)
        self.assertIn(
            "AND variant_id IN (\n"
            "      'v0_3_equal_group_internal_simulation_r150',\n"
            "      'food_market_only_v0_1'\n"
            "    )",
            sql,
        )
        self.assertIn(
            "WHERE metrics.variant_id = 'v0_3_equal_group_internal_simulation_r150'",
            sql,
        )
        self.assertIn(
            "WHERE fractions.variant_id = "
            "'v0_3_equal_group_internal_simulation_r150'",
            sql,
        )
        self.assertIn("food_overlapping_report_count", sql)
        self.assertIn("food_selected_area_share", sql)
        self.assertIn("food_report_overlap_to_area_ratio", sql)
        self.assertIn("food_report_overlap_fraction_on_common_support", sql)
        self.assertNotIn("sewer_attribute_index_v0_2_complete_case", sql)
        self.assertNotIn(
            "approved_rebuilding_admin_site_cell_footprint_buffer_150m",
            sql,
        )
        self.assertNotIn("sewer_system_type_only_v0_1", sql)
        self.assertIn(
            "CONCORDANCE_ONLY_NOT_TRAINING_SELECTION_TUNING_OR_ATTRIBUTION",
            sql,
        )
        self.assertIn("ORDINAL_SIMULATION_INDEX_NOT_PROBABILITY", sql)
        self.assertIn("NO_TRUSTED_RESULT", sql)
        self.assertNotIn("secret", sql)
        self.assertNotIn("excluded", sql)
        self.assertNotIn("25.03", sql)
        self.assertNotIn("121.54", sql)
        self.assertNotIn("CREATE MODEL", sql.upper())


if __name__ == "__main__":
    unittest.main()
