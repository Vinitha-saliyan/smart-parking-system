from datetime import datetime, timedelta, timezone
from decimal import Decimal
from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.camera import Camera
from app.models.parking_area import ParkingArea
from app.models.parking_slot import ParkingSlot
from app.models.reservation import Reservation
from app.models.user import User
from app.schemas.admin_schema import (
    AdminCameraResponse,
    AdminReservationResponse,
    DashboardStatsResponse,
)
from app.schemas.parking_schema import (
    ParkingAreaCreate,
    ParkingAreaResponse,
    ParkingAreaUpdate,
    ParkingSlotCreate,
    ParkingSlotResponse,
    ParkingSlotUpdate,
)
from app.schemas.user_schema import UserResponse
from app.services.auth_service import require_role
from app.services.parking_service import (
    bulk_create_slots,
    create_area,
    create_slot,
    delete_area,
    get_all_areas,
    get_slots_by_area,
    update_area,
)

router = APIRouter(prefix="/api/v1/admin", tags=["Admin"])
admin_dependency = Depends(require_role("ADMIN", "MANAGER"))


@router.get(
    "/areas",
    response_model=List[ParkingAreaResponse],
    dependencies=[admin_dependency],
)
async def list_parking_areas(db: AsyncSession = Depends(get_db)):
    areas = await get_all_areas(db, is_active=None)
    responses = []
    for area in areas:
        slots = await get_slots_by_area(db, area.id)
        area_data = {
            column.name: getattr(area, column.name)
            for column in area.__table__.columns
        }
        area_data["available_slots"] = sum(
            slot.status == "VACANT" for slot in slots
        )
        area_data["occupied_slots"] = sum(
            slot.status == "OCCUPIED" for slot in slots
        )
        responses.append(area_data)
    return responses


@router.post(
    "/areas",
    response_model=ParkingAreaResponse,
    dependencies=[admin_dependency],
)
async def create_parking_area(
    data: ParkingAreaCreate,
    db: AsyncSession = Depends(get_db),
):
    return await create_area(db, data)


@router.put(
    "/areas/{area_id}",
    response_model=ParkingAreaResponse,
    dependencies=[admin_dependency],
)
async def update_parking_area(
    area_id: UUID,
    data: ParkingAreaUpdate,
    db: AsyncSession = Depends(get_db),
):
    area = await update_area(db, area_id, data)
    if not area:
        raise HTTPException(status_code=404, detail="Area not found")
    return area


@router.delete("/areas/{area_id}", dependencies=[admin_dependency])
async def delete_parking_area(
    area_id: UUID,
    db: AsyncSession = Depends(get_db),
):
    await delete_area(db, area_id)
    return {"message": "Area deleted"}


@router.post(
    "/slots",
    response_model=ParkingSlotResponse,
    dependencies=[admin_dependency],
)
async def create_parking_slot(
    data: ParkingSlotCreate,
    db: AsyncSession = Depends(get_db),
):
    return await create_slot(db, data)


@router.post(
    "/slots/bulk",
    response_model=List[ParkingSlotResponse],
    dependencies=[admin_dependency],
)
async def bulk_slots(
    area_id: UUID,
    floor: int,
    prefix: str,
    count: int,
    db: AsyncSession = Depends(get_db),
):
    return await bulk_create_slots(db, area_id, floor, prefix, count)


@router.put(
    "/slots/{slot_id}",
    response_model=ParkingSlotResponse,
    dependencies=[admin_dependency],
)
async def update_parking_slot(
    slot_id: UUID,
    data: ParkingSlotUpdate,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ParkingSlot).where(ParkingSlot.id == slot_id)
    )
    slot = result.scalars().first()
    if not slot:
        raise HTTPException(status_code=404, detail="Slot not found")
    if data.status is not None:
        slot.status = data.status
    if data.slot_type is not None:
        slot.slot_type = data.slot_type
    await db.commit()
    await db.refresh(slot)
    return slot


@router.delete("/slots/{slot_id}", dependencies=[admin_dependency])
async def delete_parking_slot(
    slot_id: UUID,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ParkingSlot).where(ParkingSlot.id == slot_id)
    )
    slot = result.scalars().first()
    if not slot:
        raise HTTPException(status_code=404, detail="Slot not found")
    await db.delete(slot)
    await db.commit()
    return {"message": "Slot deleted"}


@router.get(
    "/users",
    response_model=List[UserResponse],
    dependencies=[admin_dependency],
)
async def list_users(
    search: Optional[str] = Query(default=None, max_length=100),
    db: AsyncSession = Depends(get_db),
):
    query = select(User).order_by(User.created_at.desc())
    if search and search.strip():
        term = f"%{search.strip()}%"
        query = query.where(
            or_(User.full_name.ilike(term), User.email.ilike(term))
        )
    result = await db.execute(query)
    return result.scalars().all()


@router.put(
    "/users/{user_id}/role",
    response_model=UserResponse,
    dependencies=[admin_dependency],
)
async def change_role(
    user_id: UUID,
    role: str,
    db: AsyncSession = Depends(get_db),
):
    normalized_role = role.upper()
    allowed_roles = {"USER", "ADMIN", "MANAGER", "OPERATOR", "SECURITY"}
    if normalized_role not in allowed_roles:
        raise HTTPException(status_code=400, detail="Invalid role")
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.role = normalized_role
    await db.commit()
    await db.refresh(user)
    return user


@router.put(
    "/users/{user_id}/suspend",
    response_model=UserResponse,
    dependencies=[admin_dependency],
)
async def toggle_suspend(
    user_id: UUID,
    suspend: bool,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.is_active = not suspend
    await db.commit()
    await db.refresh(user)
    return user


@router.get(
    "/stats",
    response_model=DashboardStatsResponse,
    dependencies=[admin_dependency],
)
async def get_dashboard_stats(db: AsyncSession = Depends(get_db)):
    total_users = int(await db.scalar(select(func.count(User.id))) or 0)
    active_users = int(
        await db.scalar(
            select(func.count(User.id)).where(User.is_active.is_(True))
        )
        or 0
    )
    total_areas = int(await db.scalar(select(func.count(ParkingArea.id))) or 0)
    total_slots = int(await db.scalar(select(func.count(ParkingSlot.id))) or 0)
    available_slots = int(
        await db.scalar(
            select(func.count(ParkingSlot.id)).where(
                ParkingSlot.status == "VACANT"
            )
        )
        or 0
    )
    occupied_slots = int(
        await db.scalar(
            select(func.count(ParkingSlot.id)).where(
                ParkingSlot.status == "OCCUPIED"
            )
        )
        or 0
    )
    reserved_slots = int(
        await db.scalar(
            select(func.count(ParkingSlot.id)).where(
                ParkingSlot.status == "RESERVED"
            )
        )
        or 0
    )
    total_reservations = int(
        await db.scalar(select(func.count(Reservation.id))) or 0
    )
    total_revenue = Decimal(
        await db.scalar(
            select(func.coalesce(func.sum(Reservation.total_amount), 0)).where(
                Reservation.status == "COMPLETED"
            )
        )
        or 0
    )

    today = datetime.now(timezone.utc).date()
    first_day = today - timedelta(days=6)
    revenue_result = await db.execute(
        select(
            func.date(Reservation.created_at).label("day"),
            func.coalesce(func.sum(Reservation.total_amount), 0).label(
                "amount"
            ),
        )
        .where(
            Reservation.status == "COMPLETED",
            Reservation.created_at
            >= datetime.combine(
                first_day,
                datetime.min.time(),
                tzinfo=timezone.utc,
            ),
        )
        .group_by(func.date(Reservation.created_at))
    )
    amounts_by_day = {
        row.day: Decimal(row.amount or 0) for row in revenue_result
    }
    revenue_last_7_days = [
        {
            "date": first_day + timedelta(days=index),
            "amount": amounts_by_day.get(
                first_day + timedelta(days=index), Decimal("0")
            ),
        }
        for index in range(7)
    ]

    occupancy_rate = (
        round((occupied_slots / total_slots) * 100, 1)
        if total_slots
        else 0.0
    )
    return {
        "total_users": total_users,
        "active_users": active_users,
        "total_areas": total_areas,
        "total_slots": total_slots,
        "available_slots": available_slots,
        "occupied_slots": occupied_slots,
        "reserved_slots": reserved_slots,
        "total_reservations": total_reservations,
        "total_revenue": total_revenue,
        "occupancy_rate": occupancy_rate,
        "revenue_last_7_days": revenue_last_7_days,
    }


@router.get(
    "/reservations",
    response_model=List[AdminReservationResponse],
    dependencies=[admin_dependency],
)
async def all_reservations(
    status: Optional[str] = None,
    limit: int = Query(default=100, ge=1, le=500),
    db: AsyncSession = Depends(get_db),
):
    query = (
        select(
            Reservation,
            User.full_name.label("user_name"),
            ParkingSlot.slot_id.label("slot_number"),
            ParkingArea.name.label("area_name"),
        )
        .join(User, Reservation.user_id == User.id)
        .join(ParkingSlot, Reservation.slot_id == ParkingSlot.id)
        .join(ParkingArea, Reservation.parking_area_id == ParkingArea.id)
        .order_by(Reservation.created_at.desc())
        .limit(limit)
    )
    if status and status.strip():
        query = query.where(Reservation.status == status.strip().upper())

    result = await db.execute(query)
    return [
        {
            "id": reservation.id,
            "user_id": reservation.user_id,
            "user_name": user_name,
            "slot_id": slot_number,
            "area_name": area_name,
            "start_time": reservation.start_time,
            "end_time": reservation.end_time,
            "status": reservation.status,
            "amount": reservation.total_amount or Decimal("0"),
            "created_at": reservation.created_at,
        }
        for reservation, user_name, slot_number, area_name in result.all()
    ]


@router.put(
    "/reservations/{reservation_id}/force-cancel",
    response_model=AdminReservationResponse,
    dependencies=[admin_dependency],
)
async def force_cancel(
    reservation_id: UUID,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Reservation).where(Reservation.id == reservation_id)
    )
    reservation = result.scalars().first()
    if not reservation:
        raise HTTPException(status_code=404, detail="Reservation not found")
    if reservation.status not in {"PENDING", "ACTIVE"}:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot cancel a {reservation.status.lower()} reservation",
        )

    reservation.status = "CANCELLED"
    slot_result = await db.execute(
        select(ParkingSlot).where(ParkingSlot.id == reservation.slot_id)
    )
    slot = slot_result.scalars().first()
    if slot:
        slot.status = "VACANT"
    await db.commit()

    joined = await db.execute(
        select(
            Reservation,
            User.full_name,
            ParkingSlot.slot_id,
            ParkingArea.name,
        )
        .join(User, Reservation.user_id == User.id)
        .join(ParkingSlot, Reservation.slot_id == ParkingSlot.id)
        .join(ParkingArea, Reservation.parking_area_id == ParkingArea.id)
        .where(Reservation.id == reservation_id)
    )
    reservation, user_name, slot_number, area_name = joined.one()
    return {
        "id": reservation.id,
        "user_id": reservation.user_id,
        "user_name": user_name,
        "slot_id": slot_number,
        "area_name": area_name,
        "start_time": reservation.start_time,
        "end_time": reservation.end_time,
        "status": reservation.status,
        "amount": reservation.total_amount or Decimal("0"),
        "created_at": reservation.created_at,
    }


@router.get(
    "/cameras",
    response_model=List[AdminCameraResponse],
    dependencies=[admin_dependency],
)
async def list_cameras(db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(Camera, ParkingArea.name)
        .join(ParkingArea, Camera.parking_area_id == ParkingArea.id)
        .order_by(Camera.name)
    )
    return [
        {
            "id": camera.id,
            "name": camera.name,
            "parking_area_id": camera.parking_area_id,
            "area_name": area_name,
            "floor": camera.floor,
            "status": camera.status,
            "is_active": camera.is_active,
        }
        for camera, area_name in result.all()
    ]
