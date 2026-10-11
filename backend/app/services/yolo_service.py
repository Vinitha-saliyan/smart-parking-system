from __future__ import annotations

import logging
import threading
from dataclasses import asdict, dataclass
from typing import Any, Dict, List

import cv2
import numpy as np

logger = logging.getLogger(__name__)

VEHICLE_CLASS_NAMES = frozenset({"car", "motorcycle", "bus", "truck"})


@dataclass(frozen=True)
class Detection:
    """One vehicle detected by YOLO."""

    bbox: List[float]  # [x1, y1, x2, y2]
    class_name: str
    confidence: float
    track_id: int = -1

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


class YOLOService:
    """Lazy, thread-safe YOLOv11 vehicle detector.

    Loading is deliberately delayed until the first detection request. This
    keeps the rest of the backend available even when the model file is absent
    or Ultralytics cannot download it.
    """

    def __init__(
        self,
        model_path: str,
        confidence: float = 0.5,
        iou: float = 0.45,
        image_size: int = 640,
    ) -> None:
        self.model_path = model_path
        self.confidence = confidence
        self.iou = iou
        self.image_size = image_size
        self._model: Any = None
        self._load_error: str | None = None
        self._load_lock = threading.Lock()
        self._inference_lock = threading.Lock()

    def load_model(self) -> None:
        if self._model is not None:
            return

        with self._load_lock:
            if self._model is not None:
                return

            try:
                from ultralytics import YOLO

                logger.info("Loading YOLO model from %s", self.model_path)
                self._model = YOLO(self.model_path)
                self._load_error = None
                logger.info("YOLO model loaded")
            except Exception as exc:
                self._load_error = str(exc)
                logger.exception("Unable to load YOLO model")
                raise RuntimeError(
                    "YOLO model could not be loaded. Confirm that ultralytics "
                    "is installed and YOLO_MODEL_PATH is valid."
                ) from exc

    def detect(self, frame: np.ndarray) -> List[Detection]:
        if frame is None or frame.size == 0:
            return []

        self.load_model()

        with self._inference_lock:
            results = self._model.predict(
                source=frame,
                conf=self.confidence,
                iou=self.iou,
                imgsz=self.image_size,
                verbose=False,
            )

        detections: List[Detection] = []

        for result in results:
            boxes = result.boxes
            if boxes is None or len(boxes) == 0:
                continue

            coordinates = boxes.xyxy.cpu().tolist()
            confidences = boxes.conf.cpu().tolist()
            class_ids = boxes.cls.int().cpu().tolist()
            track_ids = (
                boxes.id.int().cpu().tolist()
                if boxes.id is not None
                else [-1] * len(coordinates)
            )
            names = result.names

            for bbox, confidence, class_id, track_id in zip(
                coordinates,
                confidences,
                class_ids,
                track_ids,
            ):
                class_name = str(names.get(class_id, class_id)).lower()
                if class_name not in VEHICLE_CLASS_NAMES:
                    continue

                detections.append(
                    Detection(
                        bbox=[float(value) for value in bbox],
                        class_name=class_name,
                        confidence=float(confidence),
                        track_id=int(track_id),
                    )
                )

        return detections

    def draw_detections(
        self,
        frame: np.ndarray,
        detections: List[Detection],
    ) -> np.ndarray:
        output = frame.copy()

        for detection in detections:
            x1, y1, x2, y2 = (int(value) for value in detection.bbox)
            label = f"{detection.class_name} {detection.confidence:.2f}"

            cv2.rectangle(output, (x1, y1), (x2, y2), (255, 170, 0), 2)
            cv2.putText(
                output,
                label,
                (x1, max(18, y1 - 7)),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.5,
                (255, 255, 255),
                2,
                cv2.LINE_AA,
            )

        return output

    def get_model_info(self) -> Dict[str, Any]:
        return {
            "model_path": self.model_path,
            "confidence_threshold": self.confidence,
            "iou_threshold": self.iou,
            "inference_image_size": self.image_size,
            "vehicle_classes": sorted(VEHICLE_CLASS_NAMES),
            "loaded": self.is_loaded,
            "load_error": self._load_error,
        }

    @property
    def is_loaded(self) -> bool:
        return self._model is not None
