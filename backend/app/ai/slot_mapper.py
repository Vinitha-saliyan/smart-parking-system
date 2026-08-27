from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict, Iterable, List, Sequence

import cv2
import numpy as np


class SlotMapper:
    """Maps vehicle bounding boxes to fixed parking-space polygons."""

    def __init__(self, overlap_threshold: float = 0.20) -> None:
        self.slots: List[Dict[str, Any]] = []
        self.reference_width = 1280
        self.reference_height = 720
        self.overlap_threshold = overlap_threshold

    @classmethod
    def from_layout_file(
        cls,
        path: str | Path,
        overlap_threshold: float = 0.20,
    ) -> "SlotMapper":
        with Path(path).open("r", encoding="utf-8") as layout_file:
            layout = json.load(layout_file)

        mapper = cls(overlap_threshold=overlap_threshold)
        mapper.define_slots(
            layout["slots"],
            reference_width=int(layout.get("reference_width", 1280)),
            reference_height=int(layout.get("reference_height", 720)),
        )
        return mapper

    def define_slots(
        self,
        slot_regions: List[Dict[str, Any]],
        reference_width: int = 1280,
        reference_height: int = 720,
    ) -> None:
        validated: List[Dict[str, Any]] = []

        for slot in slot_regions:
            slot_id = str(slot.get("id", "")).strip()
            points = slot.get("points")

            if not slot_id or not isinstance(points, list) or len(points) < 3:
                raise ValueError("Every slot requires an id and at least 3 points")

            validated.append({"id": slot_id, "points": points})

        self.slots = validated
        self.reference_width = reference_width
        self.reference_height = reference_height

    def slot_ids(self) -> List[str]:
        return [str(slot["id"]) for slot in self.slots]

    def map_detections_to_slots(
        self,
        detections: Iterable[Any],
        frame_shape: Sequence[int] | None = None,
    ) -> Dict[str, bool]:
        height, width = self._frame_size(frame_shape)
        result = {str(slot["id"]): False for slot in self.slots}
        slot_geometry = [
            (
                str(slot["id"]),
                self._scaled_polygon(slot["points"], width, height),
            )
            for slot in self.slots
        ]

        # Assign each detected vehicle to only its strongest matching space.
        # This prevents one car that crosses a back-to-back boundary from
        # marking both neighbouring spaces occupied.
        for detection in detections:
            bbox = self._detection_bbox(detection)
            if bbox is None:
                continue

            x1, y1, x2, y2 = bbox
            center = ((x1 + x2) / 2.0, (y1 + y2) / 2.0)
            box_polygon = np.array(
                [[x1, y1], [x2, y1], [x2, y2], [x1, y2]],
                dtype=np.float32,
            )
            box_area = max((x2 - x1) * (y2 - y1), 1.0)
            best_slot_id: str | None = None
            best_score = -1.0

            for slot_id, slot_polygon in slot_geometry:
                slot_area = max(float(cv2.contourArea(slot_polygon)), 1.0)
                intersection_area, _ = cv2.intersectConvexConvex(
                    slot_polygon.astype(np.float32),
                    box_polygon,
                )
                overlap = float(intersection_area) / min(slot_area, box_area)
                center_inside = (
                    cv2.pointPolygonTest(slot_polygon, center, False) >= 0
                )

                if not center_inside and overlap < self.overlap_threshold:
                    continue

                # Prefer a polygon containing the vehicle centre, then use
                # overlap to resolve boundary cases.
                score = overlap + (1.0 if center_inside else 0.0)
                if score > best_score:
                    best_score = score
                    best_slot_id = slot_id

            if best_slot_id is not None:
                result[best_slot_id] = True

        return result

    def draw_slots(
        self,
        frame: np.ndarray,
        occupancy: Dict[str, bool],
    ) -> np.ndarray:
        output = frame.copy()
        overlay = output.copy()
        height, width = output.shape[:2]

        for slot in self.slots:
            slot_id = str(slot["id"])
            polygon = self._scaled_polygon(slot["points"], width, height)
            occupied = occupancy.get(slot_id, False)
            color = (0, 0, 255) if occupied else (0, 190, 0)

            cv2.fillPoly(overlay, [polygon], color)
            cv2.polylines(output, [polygon], True, color, 2, cv2.LINE_AA)

            center = polygon.mean(axis=0).astype(int)
            label = f"{slot_id} {'OCCUPIED' if occupied else 'VACANT'}"
            cv2.putText(
                output,
                label,
                (max(0, center[0] - 40), center[1]),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.38,
                (255, 255, 255),
                1,
                cv2.LINE_AA,
            )

        cv2.addWeighted(overlay, 0.14, output, 0.86, 0, output)
        return output

    def _frame_size(
        self,
        frame_shape: Sequence[int] | None,
    ) -> tuple[int, int]:
        if frame_shape is None:
            return self.reference_height, self.reference_width
        return int(frame_shape[0]), int(frame_shape[1])

    def _scaled_polygon(
        self,
        points: List[List[float]],
        width: int,
        height: int,
    ) -> np.ndarray:
        scale_x = width / self.reference_width
        scale_y = height / self.reference_height
        return np.array(
            [[round(x * scale_x), round(y * scale_y)] for x, y in points],
            dtype=np.int32,
        )

    @staticmethod
    def _detection_bbox(detection: Any) -> tuple[float, float, float, float] | None:
        bbox = (
            detection.get("bbox")
            if isinstance(detection, dict)
            else getattr(detection, "bbox", None)
        )
        if bbox is None or len(bbox) != 4:
            return None

        x1, y1, x2, y2 = (float(value) for value in bbox)
        if x2 <= x1 or y2 <= y1:
            return None
        return x1, y1, x2, y2
