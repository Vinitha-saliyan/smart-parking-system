from __future__ import annotations

import logging
import threading
import re
import math
from pathlib import Path
from dataclasses import dataclass
from typing import Any, Iterable

import cv2
import numpy as np

from app.config import settings
from app.services.yolo_service import Detection, YOLOService
from app.utils.vehicle_number import (
    is_valid_indian_vehicle_number,
    normalize_vehicle_number,
)

logger = logging.getLogger(__name__)


class GatePlateDetector(YOLOService):
    """Dedicated gate detector; does not change the occupancy YOLO service."""

    def load_model(self) -> None:
        if not Path(self.model_path).is_file():
            raise RuntimeError(
                f"Plate model missing: {self.model_path}. Copy the demo's "
                "plate_yolov8.pt into backend/models and restart the backend."
            )
        super().load_model()
        name = str(self._model.names.get(settings.GATE_PLATE_CLASS_ID, '')).lower()
        if 'plate' not in name and name not in {'license', 'licence'}:
            self._model = None
            raise RuntimeError('Gate model must be plate-trained; yolo11n.pt is a vehicle model.')

    def detect(self, frame: np.ndarray) -> list[Detection]:
        self.load_model()
        with self._inference_lock:
            result = self._model.predict(
                source=frame, classes=[settings.GATE_PLATE_CLASS_ID],
                conf=self.confidence, iou=self.iou, imgsz=640,
                device=0 if settings.PLATE_OCR_GPU else 'cpu',
                max_det=4, verbose=False,
            )[0]
        return [Detection(bbox=list(map(float, box)), class_name='license_plate',
                          confidence=float(score))
                for box, score in zip(result.boxes.xyxy.cpu().tolist(),
                                      result.boxes.conf.cpu().tolist())]


def canonical_ocr_plate(value: str) -> str:
    """Repair O/0 and I/1 only where an Indian plate format fixes the type.

    Never map H/M/N or rewrite a correctly formatted observed registration.
    Prefer the usual two-digit district format for malformed OCR strings.
    Booking verification still requires the stored registration to match.
    """
    value = normalize_vehicle_number(value)
    if is_valid_indian_vehicle_number(value):
        return value
    candidates = set()
    letters = str.maketrans({'0': 'O', '1': 'I'})
    digits = str.maketrans({'O': '0', 'I': '1'})
    for district in (2, 1):
        series = len(value) - 2 - district - 4
        if 1 <= series <= 3:
            candidate = (value[:2].translate(letters)
                         + value[2:2+district].translate(digits)
                         + value[2+district:-4].translate(letters)
                         + value[-4:].translate(digits))
            if is_valid_indian_vehicle_number(candidate):
                return candidate
    if len(value) in (9, 10) and value[2:4] == 'BH':
        candidate = (value[:2].translate(digits) + 'BH'
                     + value[4:8].translate(digits) + value[8:].translate(letters))
        if is_valid_indian_vehicle_number(candidate):
            candidates.add(candidate)
    return next(iter(candidates)) if len(candidates) == 1 else value


@dataclass
class PlateRecognitionResult:
    vehicle_number: str | None
    confidence: float | None
    annotated_frame: np.ndarray
    vehicles_detected: int


class PlateRecognitionService:
    """Detect one number plate with dedicated weights, then OCR its crop."""

    def __init__(self) -> None:
        model_path = Path(settings.GATE_PLATE_MODEL_PATH)
        if not model_path.is_absolute():
            model_path = Path(__file__).resolve().parents[2] / model_path
        self.yolo = GatePlateDetector(
            model_path=str(model_path),
            confidence=settings.GATE_PLATE_DETECT_CONFIDENCE,
            iou=settings.YOLO_IOU_THRESHOLD,
            image_size=640,
        )
        self._reader: Any = None
        self._reader_lock = threading.Lock()
        self._ocr_lock = threading.Lock()
        self._ocr_error: str | None = None

    def _load_reader(self) -> Any:
        if self._reader is not None:
            return self._reader

        with self._reader_lock:
            if self._reader is not None:
                return self._reader
            try:
                import easyocr

                logger.info("Loading EasyOCR registration reader")
                self._reader = easyocr.Reader(
                    ["en"],
                    gpu=settings.PLATE_OCR_GPU,
                    verbose=False,
                )
                self._ocr_error = None
            except Exception as exc:
                self._ocr_error = str(exc)
                logger.exception("Unable to load EasyOCR")
                raise RuntimeError(
                    "Number-plate OCR could not be loaded. Run pip install "
                    "-r requirements.txt and restart the backend."
                ) from exc
        return self._reader

    @staticmethod
    def _vehicle_crop(frame: np.ndarray, detection: Detection) -> np.ndarray:
        height, width = frame.shape[:2]
        x1, y1, x2, y2 = (int(value) for value in detection.bbox)
        pad_x = max(8, int((x2 - x1) * 0.04))
        pad_y = max(8, int((y2 - y1) * 0.04))
        x1 = max(0, x1 - pad_x)
        y1 = max(0, y1 - pad_y)
        x2 = min(width, x2 + pad_x)
        y2 = min(height, y2 + pad_y)
        return frame[y1:y2, x1:x2]

    @staticmethod
    def _plate_guide_crop(frame: np.ndarray) -> np.ndarray:
        """Return the same central region shown by the camera plate guide."""
        height, width = frame.shape[:2]
        x1 = int(width * 0.10)
        x2 = int(width * 0.90)
        y1 = int(height * 0.30)
        y2 = int(height * 0.75)
        return frame[y1:y2, x1:x2]

    @staticmethod
    def _candidate_windows(
        segments: list[tuple[str, float]],
    ) -> Iterable[tuple[str, float]]:
        for start in range(len(segments)):
            for length in range(1, min(6, len(segments) - start) + 1):
                window = segments[start : start + length]
                number = canonical_ocr_plate(
                    "".join(text for text, _ in window)
                )
                confidence = min(score for _, score in window)
                yield number, confidence

    @staticmethod
    def _prepare_ocr_canvas(plate_crop: np.ndarray) -> np.ndarray:
        """One bounded-size OCR view to keep CPU latency low."""
        minimum_width = 480
        maximum_width = 640
        width = plate_crop.shape[1]
        target_width = min(max(width, minimum_width), maximum_width)
        if width != target_width:
            scale = target_width / max(width, 1)
            plate_crop = cv2.resize(
                plate_crop,
                None,
                fx=scale,
                fy=scale,
                interpolation=cv2.INTER_CUBIC,
            )

        if plate_crop.ndim == 3:
            gray = cv2.cvtColor(plate_crop, cv2.COLOR_BGR2GRAY)
        else:
            gray = plate_crop.copy()

        gray = cv2.bilateralFilter(gray, 7, 45, 45)
        enhanced = cv2.createCLAHE(
            clipLimit=2.2,
            tileGridSize=(8, 8),
        ).apply(gray)
        blurred = cv2.GaussianBlur(enhanced, (0, 0), 1.1)
        sharpened = cv2.addWeighted(enhanced, 1.8, blurred, -0.8, 0)
        return sharpened

    @staticmethod
    def _line_segments(
        results: list[Any],
    ) -> list[list[tuple[str, float]]]:
        """Group OCR fragments by visual line before joining characters."""
        positioned: list[tuple[float, float, float, str, float]] = []
        for item in results:
            if len(item) < 3:
                continue
            text = normalize_vehicle_number(str(item[1]))
            confidence = float(item[2])
            if (not text or text == 'IND' or not math.isfinite(confidence)
                    or not max(settings.PLATE_OCR_MIN_CONFIDENCE, 0.4) <= confidence <= 1):
                continue
            box = item[0]
            try:
                xs = [float(point[0]) for point in box]
                ys = [float(point[1]) for point in box]
                x_center = sum(xs) / len(xs)
                y_center = sum(ys) / len(ys)
                height = max(max(ys) - min(ys), 1.0)
            except (IndexError, TypeError, ValueError, ZeroDivisionError):
                x_center = float(len(positioned))
                y_center = 0.0
                height = 20.0
            positioned.append((y_center, x_center, height, text, confidence))

        lines: list[dict[str, Any]] = []
        for y_center, x_center, height, text, confidence in sorted(positioned):
            matching_line = next(
                (
                    line
                    for line in lines
                    if abs(y_center - line["y"]) <= max(height, line["height"]) * 0.65
                ),
                None,
            )
            if matching_line is None:
                matching_line = {
                    "y": y_center,
                    "height": height,
                    "items": [],
                }
                lines.append(matching_line)
            matching_line["items"].append((x_center, text, confidence))

        return [
            [
                (text, confidence)
                for _, text, confidence in sorted(line["items"])
            ]
            for line in lines
        ]

    def _read_vehicle_number(
        self,
        vehicle_crop: np.ndarray,
    ) -> tuple[str | None, float | None]:
        if vehicle_crop.size == 0:
            return None, None

        ocr_image = self._prepare_ocr_canvas(vehicle_crop)

        reader = self._load_reader()
        with self._ocr_lock:
            results = reader.readtext(
                ocr_image,
                detail=1,
                paragraph=False,
                allowlist="ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789",
                decoder="greedy",
                text_threshold=0.50,
                low_text=0.25,
                link_threshold=0.25,
                contrast_ths=0.05,
                adjust_contrast=0.70,
                add_margin=0.05,
                width_ths=0.90,
            )

        candidates: list[tuple[str, float]] = []
        lines = self._line_segments(results)
        for segments in lines + ([sum(lines, [])] if len(lines) == 2 else []):
            candidates.extend(
                item
                for item in self._candidate_windows(segments)
                if is_valid_indian_vehicle_number(item[0]) and item[1] >= 0.65
            )
        if not candidates:
            return None, None

        return max(candidates, key=lambda item: item[1])

    def recognize(
        self,
        frame: np.ndarray,
        *,
        run_yolo: bool = True,
        full_frame_fallback: bool = True,
    ) -> PlateRecognitionResult:
        # Legacy keyword arguments remain accepted for existing callers.
        # Each scan now localizes a plate, independently of full-car detection.
        detections = self.yolo.detect(frame)
        annotated = self.yolo.draw_detections(frame, detections)
        if len(detections) != 1:
            return PlateRecognitionResult(None, None, annotated, len(detections))
        best_number: str | None = None
        best_confidence: float | None = None
        best_detection: Detection | None = None

        for detection in sorted(
            detections,
            key=lambda item: item.confidence,
            reverse=True,
        ):
            number, confidence = self._read_vehicle_number(
                self._vehicle_crop(frame, detection)
            )
            if number is None or confidence is None:
                continue
            if best_confidence is None or confidence > best_confidence:
                best_number = number
                best_confidence = confidence
                best_detection = detection

        if best_number and best_detection:
            x1, y1, _, _ = (int(value) for value in best_detection.bbox)
            cv2.putText(
                annotated,
                f"PLATE {best_number} ({best_confidence:.2f})",
                (x1, max(42, y1 - 28)),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.75,
                (30, 230, 80),
                2,
                cv2.LINE_AA,
            )
        elif best_number:
            height = annotated.shape[0]
            cv2.putText(
                annotated,
                f"PLATE {best_number} ({best_confidence:.2f})",
                (24, max(42, height - 28)),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.75,
                (30, 230, 80),
                2,
                cv2.LINE_AA,
            )

        return PlateRecognitionResult(
            vehicle_number=best_number,
            confidence=best_confidence,
            annotated_frame=annotated,
            vehicles_detected=len(detections),
        )

    @property
    def ocr_loaded(self) -> bool:
        return self._reader is not None

    @property
    def ocr_error(self) -> str | None:
        return self._ocr_error
