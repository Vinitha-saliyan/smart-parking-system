import unittest

from app.utils.vehicle_number import (
    is_safe_reservation_plate_match,
    is_valid_indian_vehicle_number,
    normalize_vehicle_number,
    validate_vehicle_number,
)


class VehicleNumberTest(unittest.TestCase):
    def test_normalizes_spaces_and_hyphens(self) -> None:
        self.assertEqual(normalize_vehicle_number("ka-19 ab 1234"), "KA19AB1234")

    def test_accepts_standard_registration(self) -> None:
        self.assertTrue(is_valid_indian_vehicle_number("KA19AB1234"))

    def test_accepts_bharat_registration(self) -> None:
        self.assertTrue(is_valid_indian_vehicle_number("22BH1234AA"))

    def test_rejects_incomplete_registration(self) -> None:
        with self.assertRaises(ValueError):
            validate_vehicle_number("KA19")

    def test_allows_one_missing_middle_character_for_unique_db_match(self) -> None:
        self.assertTrue(
            is_safe_reservation_plate_match("KA0MN9787", "KA01MN9787")
        )

    def test_never_fuzzy_matches_different_final_digits(self) -> None:
        self.assertFalse(
            is_safe_reservation_plate_match("KA0MN9787", "KA01MN9788")
        )

    def test_never_fuzzy_matches_different_state_code(self) -> None:
        self.assertFalse(
            is_safe_reservation_plate_match("KL01MN9787", "KA01MN9787")
        )


if __name__ == "__main__":
    unittest.main()
