from __future__ import annotations

import asyncio
import json
import logging
import tempfile
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List
from uuid import UUID, uuid4

import cv2
from fastapi.encoders import jsonable_encoder

from app.ai.slot_mapper import SlotMapper
from app.config import settings
from app.database import AsyncSessionLocal
from app.routers.websocket_router import manager
from app.services.parking_service import get_slots_by_area
from app.services.yolo_service import YOLOService

logger = logging.getLogger(__name__)

APP_DIRECTORY = Path(__file__).resolve().parents[1]
LAYOUT_DIRECTORY = APP_DIRECTORY / "data" / "slot_layouts"
WORK_DIRECTORY = Path(tempfile.gettempdir()) / "smart_parking_detection"
DEFAULT_LAYOUT = "generated_parking_1280x720"


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


@dataclass
class VideoDetectionJob:
    id: str
    original_filename: str
    source_path: Path
    area_id: str
    floor: int
    layout_name: str
    repeat_count: int
    update_database: bool
    save_annotated_video: bool
    status: str = "queued"
    progress: float = 0.0
    created_at: str = field(default_factory=_utc_now)
    started_at: str | None = None
    completed_at: str | None = None
    error: str | None = None
    warning: str | None = None
    source_duration_seconds: float = 0.0
    effective_duration_seconds: float = 0.0
    input_frames_read: int = 0
    sampled_frames_processed: int = 0
    peak_vehicle_count: int = 0
    final_occupancy: Dict[str, bool] = field(default_factory=dict)
    database_updates: int = 0
    protected_status_skips: int = 0
    result_path: Path | None = None
    stop_requested: bool = False

    def public_data(self) -> Dict[str, Any]:
        return {
            "job_id": self.id,
            "filename": self.original_filename,
            "area_id": self.area_id,
            "floor": self.floor,
            "layout": self.layout_name,
            "repeat_count": self.repeat_count,
            "update_database": self.update_database,
            "status": self.status,
            "progress_percent": round(self.progress, 2),
            "created_at": self.created_at,
            "started_at": self.started_at,
            "completed_at": self.completed_at,
            "error": self.error,
            "warning": self.warning,
            "source_duration_seconds": round(self.source_duration_seconds, 2),
            "effective_duration_seconds": round(
                self.effective_duration_seconds,
                2,
            ),
            "input_frames_read": self.input_frames_read,
            "sampled_frames_processed": self.sampled_frames_processed,
            "peak_vehicle_count": self.peak_vehicle_count,
            "final_occupancy": self.final_occupancy,
            "database_updates": self.database_updates,
            "protected_status_skips": self.protected_status_skips,
            "result_available": bool(
                self.result_path
                and self.result_path.exists()
                and self.status in {"completed", "stopped"}
            ),
        }


class _OccupancyStabilizer:
    """Requires repeated observations before confirming a status change."""

    def __init__(self, confirmations: int) -> None:
        self.confirmations = max(1, confirmations)
        self._candidate: Dict[str, bool] = {}
        self._candidate_count: Dict[str, int] = {}
        self._stable: Dict[str, bool] = {}

    def update(
        self,
        observed: Dict[str, bool],
    ) -> tuple[Dict[str, bool], Dict[str, bool]]:
        confirmed_changes: Dict[str, bool] = {}

        for slot_id, occupied in observed.items():
            if self._candidate.get(slot_id) == occupied:
                self._candidate_count[slot_id] = (
                    self._candidate_count.get(slot_id, 0) + 1
                )
            else:
                self._candidate[slot_id] = occupied
                self._candidate_count[slot_id] = 1

            if (
                self._candidate_count[slot_id] >= self.confirmations
                and self._stable.get(slot_id) != occupied
            ):
                self._stable[slot_id] = occupied
                confirmed_changes[slot_id] = occupied

        display_state = {
            slot_id: self._stable.get(slot_id, occupied)
            for slot_id, occupied in observed.items()
        }
        return display_state, confirmed_changes


class VideoDetectionService:
    def __init__(self) -> None:
        self.jobs: Dict[str, VideoDetectionJob] = {}
        self.yolo = YOLOService(
            model_path=settings.YOLO_MODEL_PATH,
            confidence=settings.YOLO_VIDEO_CONFIDENCE_THRESHOLD,
            iou=settings.YOLO_IOU_THRESHOLD,
            image_size=settings.YOLO_VIDEO_INFERENCE_SIZE,
        )

    def allocate_upload_path(self, suffix: str) -> Path:
        WORK_DIRECTORY.mkdir(parents=True, exist_ok=True)
        return WORK_DIRECTORY / f"upload_{uuid4().hex}{suffix}"

    def probe_video(self, path: Path) -> Dict[str, Any]:
        capture = cv2.VideoCapture(str(path))
        try:
            if not capture.isOpened():
                raise ValueError("OpenCV could not open this video")

            fps = float(capture.get(cv2.CAP_PROP_FPS))
            frame_count = int(capture.get(cv2.CAP_PROP_FRAME_COUNT))
            width = int(capture.get(cv2.CAP_PROP_FRAME_WIDTH))
            height = int(capture.get(cv2.CAP_PROP_FRAME_HEIGHT))
            duration = frame_count / fps if fps > 0 else 0.0

            if width <= 0 or height <= 0:
                raise ValueError("The uploaded file has no readable video frames")

            return {
                "fps": fps if fps > 0 else 24.0,
                "frame_count": frame_count,
                "width": width,
                "height": height,
                "duration_seconds": duration,
            }
        finally:
            capture.release()

    def layout_path(self, layout_name: str) -> Path:
        safe_name = Path(layout_name).name
        if safe_name != layout_name:
            raise ValueError("Invalid layout name")
        if not safe_name.endswith(".json"):
            safe_name = f"{safe_name}.json"

        path = LAYOUT_DIRECTORY / safe_name
        if not path.is_file():
            raise ValueError(f"Unknown slot layout: {layout_name}")
        return path

    def layout_info(self, layout_name: str = DEFAULT_LAYOUT) -> Dict[str, Any]:
        path = self.layout_path(layout_name)
        with path.open("r", encoding="utf-8") as layout_file:
            return json.load(layout_file)

    def load_mapper(self, layout_name: str) -> SlotMapper:
        return SlotMapper.from_layout_file(
            self.layout_path(layout_name),
            overlap_threshold=settings.YOLO_SLOT_OVERLAP_THRESHOLD,
        )

    def create_job(
        self,
        *,
        source_path: Path,
        original_filename: str,
        area_id: UUID,
        floor: int,
        layout_name: str,
        repeat_count: int,
        update_database: bool,
        save_annotated_video: bool,
        warning: str | None = None,
    ) -> VideoDetectionJob:
        metadata = self.probe_video(source_path)
        job_id = uuid4().hex
        result_path = (
            WORK_DIRECTORY / f"annotated_{job_id}.mp4"
            if save_annotated_video
            else None
        )
        job = VideoDetectionJob(
            id=job_id,
            original_filename=original_filename,
            source_path=source_path,
            area_id=str(area_id),
            floor=floor,
            layout_name=layout_name,
            repeat_count=repeat_count,
            update_database=update_database,
            save_annotated_video=save_annotated_video,
            source_duration_seconds=metadata["duration_seconds"],
            effective_duration_seconds=(
                metadata["duration_seconds"] * repeat_count
            ),
            result_path=result_path,
            warning=warning,
        )
        self.jobs[job_id] = job
        return job

    def get_job(self, job_id: str) -> VideoDetectionJob | None:
        return self.jobs.get(job_id)

    def list_jobs(self) -> List[Dict[str, Any]]:
        jobs = sorted(
            self.jobs.values(),
            key=lambda item: item.created_at,
            reverse=True,
        )
        return [job.public_data() for job in jobs]

    def request_stop(self, job_id: str) -> VideoDetectionJob | None:
        job = self.get_job(job_id)
        if job and job.status in {"queued", "processing"}:
            job.stop_requested = True
        return job

    def delete_job(self, job_id: str) -> bool:
        job = self.get_job(job_id)
        if job is None or job.status in {"queued", "processing"}:
            return False

        job.source_path.unlink(missing_ok=True)
        if job.result_path:
            job.result_path.unlink(missing_ok=True)
        self.jobs.pop(job_id, None)
        return True

    async def process_job(self, job_id: str) -> None:
        job = self.get_job(job_id)
        if job is None:
            return

        writer: cv2.VideoWriter | None = None
        job.status = "processing"
        job.started_at = _utc_now()

        try:
            metadata = self.probe_video(job.source_path)
            mapper = self.load_mapper(job.layout_name)
            stabilizer = _OccupancyStabilizer(
                settings.YOLO_OCCUPANCY_CONFIRMATIONS
            )

            source_fps = metadata["fps"]
            sample_interval = max(
                1,
                round(source_fps / max(settings.YOLO_VIDEO_SAMPLE_FPS, 0.1)),
            )
            output_fps = max(0.1, source_fps / sample_interval)
            source_frame_count = max(metadata["frame_count"], 1)
            expected_input_frames = source_frame_count * job.repeat_count

            if job.result_path:
                codec = cv2.VideoWriter_fourcc(*"mp4v")
                writer = cv2.VideoWriter(
                    str(job.result_path),
                    codec,
                    output_fps,
                    (metadata["width"], metadata["height"]),
                )
                if not writer.isOpened():
                    raise RuntimeError("Unable to create the annotated MP4")

            for _ in range(job.repeat_count):
                if job.stop_requested:
                    break

                capture = cv2.VideoCapture(str(job.source_path))
                if not capture.isOpened():
                    raise RuntimeError("Unable to reopen the uploaded video")

                try:
                    source_frame_index = 0

                    while not job.stop_requested:
                        ok, frame = capture.read()
                        if not ok:
                            break

                        job.input_frames_read += 1

                        if source_frame_index % sample_interval != 0:
                            source_frame_index += 1
                            continue

                        detections = await asyncio.to_thread(
                            self.yolo.detect,
                            frame,
                        )
                        observed = mapper.map_detections_to_slots(
                            detections,
                            frame.shape,
                        )
                        stable_occupancy, confirmed_changes = (
                            stabilizer.update(observed)
                        )
                        job.final_occupancy = stable_occupancy
                        job.sampled_frames_processed += 1
                        job.peak_vehicle_count = max(
                            job.peak_vehicle_count,
                            len(detections),
                        )

                        if job.update_database and confirmed_changes:
                            update_count, protected_count = (
                                await self._apply_confirmed_occupancy(
                                    area_id=UUID(job.area_id),
                                    floor=job.floor,
                                    changes=confirmed_changes,
                                )
                            )
                            job.database_updates += update_count
                            job.protected_status_skips += protected_count

                        if writer:
                            annotated = self.yolo.draw_detections(
                                frame,
                                detections,
                            )
                            annotated = mapper.draw_slots(
                                annotated,
                                stable_occupancy,
                            )
                            self._draw_summary(annotated, stable_occupancy)
                            writer.write(annotated)

                        job.progress = min(
                            99.9,
                            job.input_frames_read
                            / expected_input_frames
                            * 100.0,
                        )
                        source_frame_index += 1
                finally:
                    capture.release()

            job.status = "stopped" if job.stop_requested else "completed"
            if not job.stop_requested:
                job.progress = 100.0
        except Exception as exc:
            logger.exception("Video detection job %s failed", job.id)
            job.status = "failed"
            job.error = str(exc)
            if job.result_path:
                job.result_path.unlink(missing_ok=True)
        finally:
            if writer:
                writer.release()
            job.source_path.unlink(missing_ok=True)
            job.completed_at = _utc_now()

    async def _apply_confirmed_occupancy(
        self,
        *,
        area_id: UUID,
        floor: int,
        changes: Dict[str, bool],
    ) -> tuple[int, int]:
        updates: List[Any] = []
        protected_count = 0

        async with AsyncSessionLocal() as db:
            slots = await get_slots_by_area(db, area_id, floor)
            slots_by_code = {str(slot.slot_id): slot for slot in slots}

            for slot_code, occupied in changes.items():
                slot = slots_by_code.get(slot_code)
                if slot is None:
                    continue

                current_status = str(slot.status).upper()

                if occupied and current_status == "VACANT":
                    slot.status = "OCCUPIED"
                    updates.append(slot)
                elif (
                    not occupied
                    and current_status == "OCCUPIED"
                    and settings.YOLO_ALLOW_AUTOMATIC_VACATE
                ):
                    slot.status = "VACANT"
                    updates.append(slot)
                elif (
                    (occupied and current_status not in {"OCCUPIED"})
                    or (not occupied and current_status == "OCCUPIED")
                ):
                    protected_count += 1

            if updates:
                await db.commit()

                for slot in updates:
                    await self._broadcast_slot(slot)

        return len(updates), protected_count

    async def _broadcast_slot(self, slot: Any) -> None:
        database_values = {
            column.name: getattr(slot, column.name)
            for column in slot.__table__.columns
        }
        payload = jsonable_encoder(database_values)
        payload.update(
            {
                self._to_camel_case(key): value
                for key, value in payload.items()
                if "_" in key
            }
        )
        payload["type"] = "slot_status_update"

        await manager.broadcast_slot_update(
            str(slot.parking_area_id),
            payload,
        )

    @staticmethod
    def _to_camel_case(value: str) -> str:
        first, *remaining = value.split("_")
        return first + "".join(item.capitalize() for item in remaining)

    @staticmethod
    def _draw_summary(frame: Any, occupancy: Dict[str, bool]) -> None:
        occupied = sum(1 for value in occupancy.values() if value)
        total = len(occupancy)
        text = f"YOLOv11: {occupied} occupied / {total - occupied} vacant"
        cv2.rectangle(frame, (12, 12), (390, 48), (15, 15, 15), -1)
        cv2.putText(
            frame,
            text,
            (24, 38),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.65,
            (255, 255, 255),
            2,
            cv2.LINE_AA,
        )


video_detection_service = VideoDetectionService()
