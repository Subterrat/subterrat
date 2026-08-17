import csv
import io
import json
import unittest
from datetime import date
from pathlib import Path
from tempfile import TemporaryDirectory

from scripts.export_taipei_urban_renewal_bq import export_csv


FIELDS = [
    "圖層",
    "地圖名稱",
    "編號",
    "行政區",
    "位置",
    "案名",
    "目前狀態",
    "核准日期",
    "事業計畫核定日期",
    "公告日期",
    "完工年度",
    "經度",
    "緯度",
]


def _write_csv(path: Path, rows: list[dict[str, str]]) -> None:
    with path.open("w", encoding="utf-8-sig", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(rows)


class UrbanRenewalExportTest(unittest.TestCase):
    def test_exports_phase_proxy_without_outcome_data(self) -> None:
        with TemporaryDirectory() as directory:
            path = Path(directory) / "renewal.csv"
            _write_csv(
                path,
                [
                    {
                        "圖層": "已核定重建更新事業-自行劃定",
                        "地圖名稱": "A",
                        "編號": "1",
                        "行政區": "中正區",
                        "位置": "test",
                        "案名": "active",
                        "目前狀態": "核定",
                        "核准日期": "2024/1/1",
                        "事業計畫核定日期": "",
                        "公告日期": "",
                        "完工年度": "",
                        "經度": "121.52",
                        "緯度": "25.04",
                    },
                    {
                        "圖層": "已核定重建更新事業-優先劃定",
                        "地圖名稱": "B",
                        "編號": "2",
                        "行政區": "中正區",
                        "位置": "test",
                        "案名": "done",
                        "目前狀態": "完工",
                        "核准日期": "2018/1/1",
                        "事業計畫核定日期": "",
                        "公告日期": "",
                        "完工年度": "2023",
                        "經度": "121.53",
                        "緯度": "25.05",
                    },
                ],
            )
            output = io.StringIO()
            manifest = export_csv(
                path,
                date(2026, 8, 17),
                "REPOSITORY_PROVIDED_SOURCE_URI_UNDOCUMENTED",
                output,
            )

        records = [json.loads(line) for line in output.getvalue().splitlines()]
        self.assertEqual(manifest["record_count"], 2)
        self.assertEqual(manifest["primary_scenario_included_rows"], 1)
        self.assertFalse(manifest["outcome_data_read"])
        self.assertTrue(records[0]["primary_scenario_included"])
        self.assertEqual(records[0]["phase_group"], "APPROVED_NON_COMPLETE_PROXY")
        self.assertFalse(records[1]["primary_scenario_included"])
        self.assertEqual(records[1]["phase_group"], "COMPLETED")
        self.assertNotIn("source_payload_json", records[0])
        self.assertNotIn("location_text", records[0])
        self.assertNotIn("project_name", records[0])

    def test_duplicate_exact_rows_fail_closed(self) -> None:
        row = {field: "" for field in FIELDS}
        row.update(
            {
                "圖層": "自劃單元",
                "目前狀態": "",
                "經度": "121.5",
                "緯度": "25.0",
            }
        )
        with TemporaryDirectory() as directory:
            path = Path(directory) / "duplicate.csv"
            _write_csv(path, [row, row])
            with self.assertRaisesRegex(ValueError, "duplicate source rows"):
                export_csv(path, date(2026, 8, 17), "unknown", io.StringIO())


if __name__ == "__main__":
    unittest.main()
