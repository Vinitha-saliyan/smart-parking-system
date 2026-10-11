import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock
from uuid import uuid4

from app.services.gate_camera_service import GateCameraService


class GateReservationMatchingTest(unittest.IsolatedAsyncioTestCase):
    @staticmethod
    def _database_with(*vehicle_numbers: str) -> AsyncMock:
        reservations = [
            SimpleNamespace(vehicle_number=number) for number in vehicle_numbers
        ]
        scalar_result = Mock()
        scalar_result.all.return_value = reservations
        result = Mock()
        result.scalars.return_value = scalar_result
        database = AsyncMock()
        database.execute.return_value = result
        return database

    async def test_exact_match_is_preferred(self) -> None:
        service = GateCameraService.__new__(GateCameraService)
        service.mode = "ENTRY"
        database = self._database_with("KA01MN9787", "KA19HR1717")

        reservation, number, note = await service._find_reservation(
            database,
            uuid4(),
            "KA01MN9787",
        )

        self.assertIsNotNone(reservation)
        self.assertEqual(number, "KA01MN9787")
        self.assertIsNone(note)

    async def test_one_missing_character_uses_unique_live_match(self) -> None:
        service = GateCameraService.__new__(GateCameraService)
        service.mode = "ENTRY"
        database = self._database_with("KA01MN9787", "KA19HR1717")

        reservation, number, note = await service._find_reservation(
            database,
            uuid4(),
            "KA0MN9787",
        )

        self.assertIsNotNone(reservation)
        self.assertEqual(number, "KA01MN9787")
        self.assertIn("uniquely matched", note or "")

    async def test_ambiguous_close_matches_never_open_gate(self) -> None:
        service = GateCameraService.__new__(GateCameraService)
        service.mode = "ENTRY"
        database = self._database_with("KA01MN9787", "KA02MN9787")

        reservation, number, note = await service._find_reservation(
            database,
            uuid4(),
            "KA0MN9787",
        )

        self.assertIsNone(reservation)
        self.assertEqual(number, "KA0MN9787")
        self.assertIn("ambiguous", note or "")


if __name__ == "__main__":
    unittest.main()
