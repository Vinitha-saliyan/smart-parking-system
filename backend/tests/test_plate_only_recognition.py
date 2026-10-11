import unittest
from unittest.mock import Mock

import numpy as np

from app.services.plate_recognition_service import PlateRecognitionService


class PlateOnlyRecognitionTest(unittest.TestCase):
    def _service(self) -> PlateRecognitionService:
        service = PlateRecognitionService.__new__(PlateRecognitionService)
        service.yolo = Mock()
        service.yolo.detect.return_value = []
        service.yolo.draw_detections.side_effect = (
            lambda frame, detections: frame.copy()
        )
        return service

    def test_reads_plate_when_yolo_finds_no_complete_vehicle(self) -> None:
        service = self._service()
        service._read_vehicle_number = Mock(
            return_value=("KA01MN9787", 0.91)
        )
        frame = np.zeros((720, 1280, 3), dtype=np.uint8)

        result = service.recognize(
            frame,
            run_yolo=False,
            full_frame_fallback=False,
        )

        self.assertEqual(result.vehicle_number, "KA01MN9787")
        self.assertEqual(result.vehicles_detected, 0)
        service.yolo.detect.assert_not_called()
        service._read_vehicle_number.assert_called_once()
        scanned_crop = service._read_vehicle_number.call_args.args[0]
        self.assertLess(scanned_crop.shape[0], frame.shape[0])
        self.assertLess(scanned_crop.shape[1], frame.shape[1])

    def test_full_frame_is_fallback_when_guide_has_no_plate(self) -> None:
        service = self._service()
        service._read_vehicle_number = Mock(
            side_effect=[(None, None), ("KA19HR1717", 0.84)]
        )
        frame = np.zeros((720, 1280, 3), dtype=np.uint8)

        result = service.recognize(frame, run_yolo=False)

        self.assertEqual(result.vehicle_number, "KA19HR1717")
        self.assertEqual(service._read_vehicle_number.call_count, 2)
        full_frame = service._read_vehicle_number.call_args_list[1].args[0]
        self.assertIs(full_frame, frame)

    def test_periodic_comprehensive_scan_keeps_yolo_working(self) -> None:
        service = self._service()
        service._read_vehicle_number = Mock(return_value=(None, None))
        frame = np.zeros((720, 1280, 3), dtype=np.uint8)

        result = service.recognize(frame, run_yolo=True)

        self.assertIsNone(result.vehicle_number)
        service.yolo.detect.assert_called_once_with(frame)
        service.yolo.draw_detections.assert_called_once()


if __name__ == "__main__":
    unittest.main()
