import io
import json
import unittest
from datetime import date
from pathlib import Path
from tempfile import TemporaryDirectory

from scripts.export_taipei_sanitary_pipe_bq import export_xml


def _write_xml(path: Path, members: str) -> None:
    path.write_text(
        """<?xml version="1.0" encoding="utf-8"?>
<UTL xmlns="https://standards.moi.gov.tw/schema/utilityex"
     xmlns:gml="http://www.opengis.net/gml">"""
        + members
        + "</UTL>",
        encoding="utf-8",
    )


def _member(
    segment_id: str,
    *,
    installed: str = "2020-01-01",
    use_status: str = "0",
    data_status: str = "0",
    width: str = "200",
    height: str = "0",
) -> str:
    return f"""
<gml:featureMember>
  <UTL_管線>
    <geometry><gml:LineString srsName="EPSG:3826" srsDimension="3"><gml:posList>300000 2770000 5 300010 2770010 4</gml:posList></gml:LineString></geometry>
    <識別碼>{segment_id}</識別碼>
    <起點編號>START-{segment_id}</起點編號>
    <終點編號>END-{segment_id}</終點編號>
    <作業區分>1</作業區分>
    <設置日期><gml:TimeInstant><gml:timePosition>{installed}</gml:timePosition></gml:TimeInstant></設置日期>
    <尺寸單位>0</尺寸單位>
    <管徑寬度>{width}</管徑寬度>
    <管徑高度>{height}</管徑高度>
    <管線材料>PVC</管線材料>
    <起點埋設深度>1</起點埋設深度>
    <終點埋設深度>2</終點埋設深度>
    <管線長度>14.142135624</管線長度>
    <管線型態>0</管線型態>
    <使用狀態>{use_status}</使用狀態>
    <資料狀態>{data_status}</資料狀態>
  </UTL_管線>
</gml:featureMember>
"""


class BigQueryPipeExportTest(unittest.TestCase):
    def test_exports_typed_outcome_free_records_and_manifest(self):
        with TemporaryDirectory() as directory:
            xml_path = Path(directory) / "pipe.xml"
            _write_xml(
                xml_path,
                _member("A")
                + _member(
                    "B",
                    installed="2027-01-01",
                    use_status="1",
                    data_status="1",
                    height="100",
                ),
            )
            output = io.StringIO()
            manifest = export_xml(
                [xml_path],
                ["resource-1"],
                date(2026, 2, 23),
                output,
            )

        rows = [json.loads(line) for line in output.getvalue().splitlines()]
        self.assertEqual(manifest["record_count"], 2)
        self.assertEqual(manifest["unique_segment_ids"], 2)
        self.assertFalse(manifest["outcome_data_read"])
        self.assertEqual(rows[0]["circular_diameter_m"], 0.2)
        self.assertEqual(rows[0]["mean_cover_depth_m"], 1.5)
        self.assertTrue(rows[0]["geometry_wkt_wgs84"].startswith("LINESTRING"))
        self.assertTrue(rows[0]["is_active"])
        self.assertIn("INSTALL_DATE_AFTER_SNAPSHOT", rows[1]["quality_flags"])
        self.assertIn("NOT_ACTIVE", rows[1]["quality_flags"])
        self.assertIn("NOT_SURVEYED", rows[1]["quality_flags"])
        self.assertIn(
            "NON_CIRCULAR_OR_INVALID_DIAMETER", rows[1]["quality_flags"]
        )

    def test_duplicate_segment_id_fails_closed(self):
        with TemporaryDirectory() as directory:
            xml_path = Path(directory) / "duplicate.xml"
            _write_xml(xml_path, _member("A") + _member("A"))
            with self.assertRaisesRegex(ValueError, "duplicate segment ID"):
                export_xml(
                    [xml_path],
                    ["resource-1"],
                    date(2026, 2, 23),
                    io.StringIO(),
                )


if __name__ == "__main__":
    unittest.main()
