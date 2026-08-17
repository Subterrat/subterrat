import unittest

from scripts.geocode_unused_buildings_from_taipei_addresses import (
    normalize_address,
)


class AddressNormalizationTest(unittest.TestCase):
    def test_strips_floor_and_normalizes_subnumber(self):
        self.assertEqual(normalize_address("保安街47-1號3樓"), "保安街47之1號")

    def test_normalizes_fullwidth_and_section_number(self):
        self.assertEqual(
            normalize_address("陽明路１段４８巷９號１樓"),
            "陽明路一段48巷9號",
        )

    def test_strips_parenthetical_note(self):
        self.assertEqual(
            normalize_address("中正路589號（橋下空間）"),
            "中正路589號",
        )


if __name__ == "__main__":
    unittest.main()
