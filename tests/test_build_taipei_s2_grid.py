import unittest

from pyproj import Geod
from s2sphere import CellId, LatLng
from shapely.geometry import box

from scripts.build_taipei_s2_grid import (
    build_rows,
    cell_polygon,
    to_signed_int64,
)


class GridBuilderTest(unittest.TestCase):
    def test_signed_int64_conversion(self):
        self.assertEqual(to_signed_int64((1 << 63) - 1), (1 << 63) - 1)
        self.assertEqual(to_signed_int64(1 << 63), -(1 << 63))
        self.assertEqual(to_signed_int64((1 << 64) - 1), -1)

    def test_cell_polygon_contains_source_point(self):
        point = LatLng.from_degrees(25.04, 121.56)
        cell_id = CellId.from_lat_lng(point).parent(15)
        polygon = cell_polygon(cell_id)
        self.assertTrue(polygon.is_valid)
        self.assertTrue(polygon.contains(box(121.56, 25.04, 121.56, 25.04)))

    def test_small_boundary_produces_unique_positive_area_rows(self):
        boundary = box(121.55, 25.03, 121.57, 25.05)
        rows = list(build_rows(boundary, 15, "a" * 64))
        self.assertGreater(len(rows), 0)
        self.assertEqual(len(rows), len({row["cell_id"] for row in rows}))
        self.assertTrue(all(row["eligible_area_m2"] > 0 for row in rows))
        geod = Geod(ellps="GRS80")
        expected = abs(geod.geometry_area_perimeter(boundary)[0])
        actual = sum(row["eligible_area_m2"] for row in rows)
        self.assertAlmostEqual(actual, expected, delta=expected * 0.001)


if __name__ == "__main__":
    unittest.main()
