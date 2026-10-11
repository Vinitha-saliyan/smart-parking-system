from __future__ import annotations

import asyncio
from pathlib import Path
from typing import Any, Dict, List
from uuid import UUID

from fastapi import (
    APIRouter,
    BackgroundTasks,
    Depends,
    File,
    Form,
    HTTPException,
    UploadFile,
    status,
)
from fastapi.responses import FileResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.services.parking_service import get_slots_by_area
from app.services.video_detection_service import (
    DEFAULT_LAYOUT,
    video_detection_service,
)

router = APIRouter(prefix="/api/v1/detection", tags=["YOLO Detection"])

ALLOWED_VIDEO_EXTENSIONS = {".mp4", ".avi", ".mov", ".mkv"}


def _job_response(job: Any) -> Dict[str, Any]:
    data = job.public_data()
    data["status_url"] = f"/api/v1/detection/jobs/{job.id}"
    data["result_video_url"] = (
        f"/api/v1/detection/jobs/{job.id}/video"
        if data["result_available"]
        else None
    )
    return data


@router.get("/model")
async def model_information(load: bool = False) -> Dict[str, Any]:
    if load:
        try:
            await asyncio.to_thread(video_detection_service.yolo.load_model)
        except RuntimeError as exc:
            raise HTTPException(status_code=503, detail=str(exc)) from exc
    return video_detection_service.yolo.get_model_info()


@router.get("/layouts/default")
async def default_layout() -> Dict[str, Any]:
    try:
        return video_detection_service.layout_info(DEFAULT_LAYOUT)
    except (OSError, ValueError) as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.post("/videos", status_code=status.HTTP_202_ACCEPTED)
async def upload_recorded_video(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    area_id: UUID = Form(...),
    floor: int = Form(1, ge=1),
    layout_name: str = Form(DEFAULT_LAYOUT),
    repeat_count: int = Form(1, ge=1, le=360),
    update_database: bool = Form(False),
    save_annotated_video: bool = Form(True),
    db: AsyncSession = Depends(get_db),
) -> Dict[str, Any]:
    original_filename = Path(file.filename or "recorded_video.mp4").name
    suffix = Path(original_filename).suffix.lower()

    if suffix not in ALLOWED_VIDEO_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail="Upload an MP4, AVI, MOV, or MKV video",
        )

    try:
        mapper = video_detection_service.load_mapper(layout_name)
    except (OSError, ValueError) as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    slots = await get_slots_by_area(db, area_id, floor)
    if not slots:
        raise HTTPException(
            status_code=404,
            detail="No parking slots exist for this area and floor",
        )

    database_slot_ids = {str(slot.slot_id) for slot in slots}
    mapped_slot_ids = set(mapper.slot_ids())
    matching_slot_ids = database_slot_ids & mapped_slot_ids
    if not matching_slot_ids:
        raise HTTPException(
            status_code=400,
            detail=(
                "The selected area does not contain any slot IDs from the "
                f"layout. Expected examples: {', '.join(mapper.slot_ids()[:5])}"
            ),
        )

    missing_slots = sorted(mapped_slot_ids - database_slot_ids)
    warning = None
    if missing_slots:
        warning = (
            "These layout slots are not present in the selected floor and will "
            f"not update the database: {', '.join(missing_slots)}"
        )

    upload_path = video_detection_service.allocate_upload_path(suffix)
    maximum_bytes = settings.YOLO_MAX_VIDEO_UPLOAD_MB * 1024 * 1024
    uploaded_bytes = 0

    try:
        with upload_path.open("wb") as output_file:
            while chunk := await file.read(1024 * 1024):
                uploaded_bytes += len(chunk)
                if uploaded_bytes > maximum_bytes:
                    raise HTTPException(
                        status_code=413,
                        detail=(
                            "Video exceeds the configured "
                            f"{settings.YOLO_MAX_VIDEO_UPLOAD_MB} MB limit"
                        ),
                    )
                output_file.write(chunk)

        if uploaded_bytes == 0:
            raise HTTPException(status_code=400, detail="The video file is empty")

        try:
            video_detection_service.probe_video(upload_path)
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=str(exc)) from exc

        job = video_detection_service.create_job(
            source_path=upload_path,
            original_filename=original_filename,
            area_id=area_id,
            floor=floor,
            layout_name=layout_name,
            repeat_count=repeat_count,
            update_database=update_database,
            save_annotated_video=save_annotated_video,
            warning=warning,
        )
        background_tasks.add_task(
            video_detection_service.process_job,
            job.id,
        )
        return _job_response(job)
    except Exception:
        if upload_path.exists() and not any(
            job.source_path == upload_path
            for job in video_detection_service.jobs.values()
        ):
            upload_path.unlink(missing_ok=True)
        raise
    finally:
        await file.close()


@router.get("/jobs")
async def list_video_jobs() -> List[Dict[str, Any]]:
    return [
        _job_response(job)
        for job in sorted(
            video_detection_service.jobs.values(),
            key=lambda item: item.created_at,
            reverse=True,
        )
    ]


@router.get("/jobs/{job_id}")
async def video_job_status(job_id: str) -> Dict[str, Any]:
    job = video_detection_service.get_job(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="Detection job not found")
    return _job_response(job)


@router.post("/jobs/{job_id}/stop")
async def stop_video_job(job_id: str) -> Dict[str, Any]:
    job = video_detection_service.request_stop(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="Detection job not found")
    return _job_response(job)


@router.get("/jobs/{job_id}/video")
async def download_annotated_video(job_id: str) -> FileResponse:
    job = video_detection_service.get_job(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="Detection job not found")
    if job.status not in {"completed", "stopped"}:
        raise HTTPException(status_code=409, detail="Detection is not finished")
    if job.result_path is None or not job.result_path.is_file():
        raise HTTPException(
            status_code=404,
            detail="This job has no annotated result video",
        )

    return FileResponse(
        path=job.result_path,
        media_type="video/mp4",
        filename=f"yolo_{Path(job.original_filename).stem}.mp4",
    )


@router.delete("/jobs/{job_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_video_job(job_id: str) -> None:
    job = video_detection_service.get_job(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="Detection job not found")
    if job.status in {"queued", "processing"}:
        raise HTTPException(
            status_code=409,
            detail="Stop the job before deleting it",
        )
    video_detection_service.delete_job(job_id)
