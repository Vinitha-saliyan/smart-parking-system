from typing import List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Response
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.gate_event import GateEvent
from app.models.parking_slot import ParkingSlot
from app.models.user import User
from app.schemas.parking_schema import ParkingSlotResponse
from app.schemas.gate_schema import (
    GateCameraStart,
    GateEventResponse,
    GateModeUpdate,
    GateStatusResponse,
    WalkInAdmissionRequest,
    WalkInPaymentRequest,
)
from app.services.auth_service import require_role
from app.services.gate_camera_service import gate_camera_service
from app.services.walk_in_service import (
    create_walk_in_session,
    get_walk_in_slots,
    record_walk_in_payment,
)

router = APIRouter(prefix="/api/v1/gate", tags=["ANPR Gate"])
admin_dependency = Depends(
    require_role("ADMIN", "MANAGER", "OPERATOR", "SECURITY")
)


@router.get(
    "/status",
    response_model=GateStatusResponse,
    dependencies=[admin_dependency],
)
async def gate_status() -> dict:
    return gate_camera_service.status()


@router.post(
    "/camera/start",
    response_model=GateStatusResponse,
    dependencies=[admin_dependency],
)
async def start_camera(data: GateCameraStart) -> dict:
    await gate_camera_service.start(
        data.mode,
        data.parking_area_id,
        data.camera_index,
    )
    return gate_camera_service.status()


@router.post(
    "/camera/stop",
    response_model=GateStatusResponse,
    dependencies=[admin_dependency],
)
async def stop_camera() -> dict:
    await gate_camera_service.stop()
    return gate_camera_service.status()


@router.put(
    "/mode",
    response_model=GateStatusResponse,
    dependencies=[admin_dependency],
)
async def set_gate_mode(data: GateModeUpdate) -> dict:
    await gate_camera_service.set_mode(data.mode, data.parking_area_id)
    return gate_camera_service.status()


@router.get(
    "/walk-in-slots",
    response_model=List[ParkingSlotResponse],
    dependencies=[admin_dependency],
)
async def list_walk_in_slots(
    parking_area_id: UUID = Query(...),
    db: AsyncSession = Depends(get_db),
):
    return await get_walk_in_slots(db, parking_area_id)


@router.post(
    "/walk-ins/admit",
    response_model=GateStatusResponse,
    dependencies=[admin_dependency],
)
async def admit_walk_in(
    data: WalkInAdmissionRequest,
    db: AsyncSession = Depends(get_db),
) -> dict:
    if gate_camera_service.mode != "ENTRY":
        raise HTTPException(status_code=409, detail="Switch the camera to Entry Mode")
    if gate_camera_service.last_vehicle_number != data.vehicle_number:
        raise HTTPException(
            status_code=409,
            detail="Scan this number plate in Entry Mode before assigning W01 or W02",
        )
    reservation, event = await create_walk_in_session(
        db,
        data.parking_area_id,
        data.slot_id,
        data.vehicle_number,
    )
    await gate_camera_service.show_walk_in_admission(reservation, event.message)
    return gate_camera_service.status()


@router.post(
    "/walk-ins/{reservation_id}/payment",
    response_model=GateStatusResponse,
)
async def pay_walk_in_exit(
    reservation_id: UUID,
    data: WalkInPaymentRequest,
    current_admin: User = Depends(
        require_role("ADMIN", "MANAGER", "OPERATOR", "SECURITY")
    ),
    db: AsyncSession = Depends(get_db),
) -> dict:
    reservation, settlement, event = await record_walk_in_payment(
        db,
        reservation_id,
        data.method,
        current_admin.id,
    )
    await gate_camera_service.open_after_manual_payment(
        reservation,
        settlement,
        event.message,
    )
    return gate_camera_service.status()


@router.get("/camera/snapshot", dependencies=[admin_dependency])
async def camera_snapshot() -> Response:
    snapshot = gate_camera_service.snapshot()
    if snapshot is None:
        raise HTTPException(
            status_code=404,
            detail="Camera preview is not available yet",
        )
    return Response(
        content=snapshot,
        media_type="image/jpeg",
        headers={"Cache-Control": "no-store, no-cache, must-revalidate"},
    )


@router.get(
    "/events",
    response_model=List[GateEventResponse],
    dependencies=[admin_dependency],
)
async def list_gate_events(
    limit: int = Query(default=30, ge=1, le=200),
    db: AsyncSession = Depends(get_db),
) -> list[dict]:
    result = await db.execute(
        select(GateEvent, ParkingSlot.slot_id)
        .outerjoin(ParkingSlot, GateEvent.slot_id == ParkingSlot.id)
        .order_by(GateEvent.created_at.desc())
        .limit(limit)
    )
    return [
        {
            "id": event.id,
            "parking_area_id": event.parking_area_id,
            "reservation_id": event.reservation_id,
            "slot_id": event.slot_id,
            "slot_number": slot_number,
            "event_type": event.event_type,
            "vehicle_number": event.vehicle_number,
            "ocr_confidence": event.ocr_confidence,
            "authorized": event.authorized,
            "gate_state": event.gate_state,
            "message": event.message,
            "created_at": event.created_at,
        }
        for event, slot_number in result.all()
    ]
