from __future__ import annotations

from typing import Any, Dict, List

import numpy as np

from app.config import settings
from app.services.yolo_service import Detection, YOLOService


class VehicleDetector:
    """Compatibility wrapper for code that still imports VehicleDetector."""

    def __init__(self) -> None:
        self._service = YOLOService(
            model_path=settings.YOLO_MODEL_PATH,
            confidence=settings.YOLO_CONFIDENCE_THRESHOLD,
            iou=settings.YOLO_IOU_THRESHOLD,
        )

    @property
    def model(self) -> YOLOService:
        return self._service

    def load_model(self, path: str) -> None:
        self._service = YOLOService(
            model_path=path,
            confidence=settings.YOLO_CONFIDENCE_THRESHOLD,
            iou=settings.YOLO_IOU_THRESHOLD,
        )
        self._service.load_model()

    def detect_vehicles(self, frame: np.ndarray) -> List[Dict[str, Any]]:
        return [item.to_dict() for item in self._service.detect(frame)]

    def draw_detections(
        self,
        frame: np.ndarray,
        detections: List[Dict[str, Any]],
    ) -> np.ndarray:
        typed_detections = [
            Detection(
                bbox=[float(value) for value in item["bbox"]],
                class_name=str(item["class_name"]),
                confidence=float(item["confidence"]),
                track_id=int(item.get("track_id", -1)),
            )
            for item in detections
        ]
        return self._service.draw_detections(frame, typed_detections)
