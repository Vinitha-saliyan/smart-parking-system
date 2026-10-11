import unittest
from decimal import Decimal

from pydantic import ValidationError

from app.schemas.gate_schema import WalkInPaymentRequest
from app.services.parking_pricing import (
    calculate_checkout_balance,
    calculate_parking_total,
)


class WalkInBillingTest(unittest.TestCase):
    def test_unpaid_advance_owes_full_first_hour(self) -> None:
        total = calculate_parking_total(45 * 60)
        self.assertEqual(total, Decimal("20.00"))
        self.assertEqual(
            calculate_checkout_balance(total, advance_paid=False),
            Decimal("20.00"),
        )

    def test_verified_advance_is_deducted(self) -> None:
        total = calculate_parking_total(45 * 60)
        self.assertEqual(
            calculate_checkout_balance(total, advance_paid=True),
            Decimal("10.00"),
        )

    def test_extra_started_hour_adds_five_rupees(self) -> None:
        total = calculate_parking_total((60 * 60) + 1)
        self.assertEqual(total, Decimal("25.00"))
        self.assertEqual(
            calculate_checkout_balance(total, advance_paid=False),
            Decimal("25.00"),
        )

    def test_manual_walk_in_payment_accepts_only_cash_or_upi(self) -> None:
        self.assertEqual(WalkInPaymentRequest(method="CASH").method, "CASH")
        self.assertEqual(WalkInPaymentRequest(method="UPI").method, "UPI")
        with self.assertRaises(ValidationError):
            WalkInPaymentRequest(method="CARD")


if __name__ == "__main__":
    unittest.main()
