import asyncio
import sys
import threading
import time
import types
import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock

import numpy as np

# Isolate this service test from the application's router import graph.
realtime_stub = types.ModuleType("app.services.realtime_service")


async def _unused_broadcast(*args, **kwargs) -> None:
    return None


realtime_stub.broadcast_gate_event = _unused_broadcast
realtime_stub.broadcast_slot_status = _unused_broadcast
sys.modules["app.services.realtime_service"] = realtime_stub

from app.services.gate_camera_service import GateCameraService


class _SlowRecognizer:
    def __init__(self) -> None:
        self.started = threading.Event()

    def recognize(self, frame, **options):
        self.started.set()
        time.sleep(0.10)
        return SimpleNamespace(vehicle_number=None, confidence=None)


class GateCameraPerformanceTest(unittest.IsolatedAsyncioTestCase):
    def test_first_scan_is_fast_and_fourth_scan_keeps_yolo(self) -> None:
        self.assertFalse(GateCameraService._is_comprehensive_scan(1))
        self.assertFalse(GateCameraService._is_comprehensive_scan(2))
        self.assertFalse(GateCameraService._is_comprehensive_scan(3))
        self.assertTrue(GateCameraService._is_comprehensive_scan(4))

    async def test_recognition_does_not_block_live_event_loop(self) -> None:
        service = GateCameraService.__new__(GateCameraService)
        service.recognizer = _SlowRecognizer()
        service.camera_running = True
        service._recognition_epoch = 7
        service.error = None
        service.message = "Camera active"
        frame = np.zeros((90, 160, 3), dtype=np.uint8)

        task = asyncio.create_task(
            service._recognize_frame(frame, epoch=7, run_yolo=False)
        )
        for _ in range(100):
            if service.recognizer.started.is_set():
                break
            await asyncio.sleep(0.001)

        self.assertTrue(service.recognizer.started.is_set())
        self.assertFalse(task.done())
        await task
        self.assertIsNone(service.error)

    async def test_high_confidence_plate_proceeds_in_one_scan(self) -> None:
        service = GateCameraService.__new__(GateCameraService)
        service.mode = "ENTRY"
        service.last_vehicle_number = None
        service.last_raw_vehicle_number = None
        service.last_ocr_confidence = None
        service.last_decision_seconds = None
        service.last_authorized = None
        service.message = "Camera active"
        service._candidate_plate = None
        service._candidate_count = 0
        service._candidate_started_at = None
        service._last_processed = {}
        service._process_plate = AsyncMock(return_value="KA01MN9787")

        await service._observe_plate("KA01MN9787", 0.91)

        service._process_plate.assert_awaited_once_with("KA01MN9787", 0.91)
        self.assertEqual(service.last_vehicle_number, "KA01MN9787")

    async def test_low_confidence_plate_still_requires_confirmation(self) -> None:
        service = GateCameraService.__new__(GateCameraService)
        service.mode = "ENTRY"
        service.last_vehicle_number = None
        service.last_raw_vehicle_number = None
        service.last_ocr_confidence = None
        service.last_decision_seconds = None
        service.last_authorized = None
        service.message = "Camera active"
        service._candidate_plate = None
        service._candidate_count = 0
        service._candidate_started_at = None
        service._last_processed = {}
        service._process_plate = AsyncMock(return_value="KA01MN9787")

        await service._observe_plate("KA01MN9787", 0.51)
        service._process_plate.assert_not_awaited()
        self.assertEqual(service.message, "Confirming plate KA01MN9787")

        await service._observe_plate("KA01MN9787", 0.51)
        service._process_plate.assert_awaited_once_with("KA01MN9787", 0.51)


if __name__ == "__main__":
    unittest.main()
