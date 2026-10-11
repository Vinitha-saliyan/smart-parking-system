from __future__ import annotations

from datetime import datetime, timedelta, timezone
from decimal import Decimal
from uuid import UUID, uuid4

from fastapi import HTTPException
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import AsyncSessionLocal
from app.models.gate_event import GateEvent
from app.models.parking_area import ParkingArea
from app.models.parking_settlement import ParkingSettlement
from app.models.parking_slot import ParkingSlot
from app.models.reservation import Reservation
from app.models.user import User
from app.services.auth_service import hash_password
from app.services.realtime_service import broadcast_slot_status


WALK_IN_SYSTEM_EMAIL = "walkin@smartparking.local"
WALK_IN_SLOT_NUMBERS = ("W01", "W02")


async def ensure_walk_in_slots_for_area(
    db: AsyncSession,
    area: ParkingArea,
) -> None:
    slot_result = await db.execute(
        select(ParkingSlot).where(
            ParkingSlot.parking_area_id == area.id,
            ParkingSlot.slot_id.in_(WALK_IN_SLOT_NUMBERS),
        )
    )
    existing = {slot.slot_id: slot for slot in slot_result.scalars()}
    for index, slot_number in enumerate(WALK_IN_SLOT_NUMBERS):
        slot = existing.get(slot_number)
        if slot:
            slot.slot_type = "WALK_IN"
            continue
        db.add(
            ParkingSlot(
                slot_id=slot_number,
                parking_area_id=area.id,
                floor=1,
                slot_type="WALK_IN",
                status="VACANT",
                position_x=index,
                position_y=4,
            )
        )

    await db.flush()
    area.total_slots = int(
        await db.scalar(
            select(func.count(ParkingSlot.id)).where(
                ParkingSlot.parking_area_id == area.id
            )
        )
        or 0
    )


async def ensure_walk_in_resources() -> None:
    """Create the non-login walk-in owner and W01/W02 for every area."""
    async with AsyncSessionLocal() as db:
        user_result = await db.execute(
            select(User).where(User.email == WALK_IN_SYSTEM_EMAIL)
        )
        walk_in_user = user_result.scalars().first()
        if not walk_in_user:
            walk_in_user = User(
                email=WALK_IN_SYSTEM_EMAIL,
                hashed_password=hash_password(uuid4().hex),
                full_name="Walk-in Driver",
                role="SYSTEM",
                is_active=False,
                is_verified=True,
            )
            db.add(walk_in_user)

        area_result = await db.execute(select(ParkingArea))
        areas = list(area_result.scalars().all())
        for area in areas:
            await ensure_walk_in_slots_for_area(db, area)
        await db.commit()


async def get_walk_in_slots(
    db: AsyncSession,
    parking_area_id: UUID,
) -> list[ParkingSlot]:
    result = await db.execute(
        select(ParkingSlot)
        .where(
            ParkingSlot.parking_area_id == parking_area_id,
            ParkingSlot.slot_type == "WALK_IN",
            ParkingSlot.slot_id.in_(WALK_IN_SLOT_NUMBERS),
        )
        .order_by(ParkingSlot.slot_id)
    )
    return list(result.scalars().all())


async def create_walk_in_session(
    db: AsyncSession,
    parking_area_id: UUID,
    slot_id: UUID,
    vehicle_number: str,
) -> tuple[Reservation, GateEvent]:
    user_result = await db.execute(
        select(User).where(User.email == WALK_IN_SYSTEM_EMAIL)
    )
    walk_in_user = user_result.scalars().first()
    if not walk_in_user:
        raise HTTPException(
            status_code=503,
            detail="Walk-in resources are not ready; restart the backend",
        )

    slot_result = await db.execute(
        select(ParkingSlot)
        .where(
            ParkingSlot.id == slot_id,
            ParkingSlot.parking_area_id == parking_area_id,
            ParkingSlot.slot_type == "WALK_IN",
            ParkingSlot.slot_id.in_(WALK_IN_SLOT_NUMBERS),
        )
        .with_for_update()
    )
    slot = slot_result.scalars().first()
    if not slot:
        raise HTTPException(
            status_code=404,
            detail="Select walk-in slot W01 or W02",
        )
    if slot.status != "VACANT":
        raise HTTPException(
            status_code=409,
            detail=f"Walk-in slot {slot.slot_id} is not vacant",
        )

    existing_result = await db.execute(
        select(Reservation.id).where(
            Reservation.parking_area_id == parking_area_id,
            Reservation.vehicle_number == vehicle_number,
            Reservation.status.in_(
                [
                    "PAYMENT_PENDING",
                    "PENDING",
                    "ACTIVE",
                    "CHECKOUT_PAYMENT_PENDING",
                ]
            ),
        )
    )
    if existing_result.first():
        raise HTTPException(
            status_code=409,
            detail="This vehicle already has an active parking session",
        )

    now = datetime.now(timezone.utc)
    reservation = Reservation(
        user_id=walk_in_user.id,
        slot_id=slot.id,
        parking_area_id=parking_area_id,
        start_time=now,
        end_time=now + timedelta(hours=1),
        actual_check_in=now,
        status="ACTIVE",
        booking_type="WALK_IN",
        advance_paid=False,
        vehicle_number=vehicle_number,
        total_amount=None,
    )
    slot.status = "OCCUPIED"
    db.add(reservation)
    await db.flush()

    event = GateEvent(
        parking_area_id=parking_area_id,
        reservation_id=reservation.id,
        slot_id=slot.id,
        event_type="ENTRY",
        vehicle_number=vehicle_number,
        authorized=True,
        gate_state="OPEN",
        message=f"Walk-in admitted to {slot.slot_id}. Entry gate opened.",
    )
    db.add(event)
    await db.commit()
    await db.refresh(event)

    loaded_result = await db.execute(
        select(Reservation)
        .options(selectinload(Reservation.slot))
        .where(Reservation.id == reservation.id)
    )
    loaded = loaded_result.scalars().one()
    await broadcast_slot_status(loaded.slot)
    return loaded, event


async def record_walk_in_payment(
    db: AsyncSession,
    reservation_id: UUID,
    payment_method: str,
    admin_user_id: UUID,
) -> tuple[Reservation, ParkingSettlement, GateEvent]:
    result = await db.execute(
        select(Reservation)
        .options(selectinload(Reservation.slot))
        .where(Reservation.id == reservation_id)
        .with_for_update()
    )
    reservation = result.scalars().first()
    if not reservation or reservation.booking_type != "WALK_IN":
        raise HTTPException(status_code=404, detail="Walk-in session not found")
    if reservation.status != "CHECKOUT_PAYMENT_PENDING":
        raise HTTPException(
            status_code=400,
            detail="Scan this walk-in vehicle in Exit Mode before recording payment",
        )

    settlement_result = await db.execute(
        select(ParkingSettlement).where(
            ParkingSettlement.reservation_id == reservation.id
        )
    )
    settlement = settlement_result.scalars().first()
    if not settlement:
        raise HTTPException(status_code=404, detail="Walk-in checkout charge not found")
    if settlement.status == "COMPLETED":
        raise HTTPException(status_code=409, detail="Walk-in payment is already recorded")

    settlement.status = "COMPLETED"
    settlement.payment_method = payment_method
    settlement.recorded_by = admin_user_id
    reservation.status = "COMPLETED"
    reservation.slot.status = "VACANT"

    event_result = await db.execute(
        select(GateEvent)
        .where(
            GateEvent.reservation_id == reservation.id,
            GateEvent.event_type == "EXIT",
        )
        .order_by(GateEvent.created_at.desc())
    )
    event = event_result.scalars().first()
    message = (
        f"₹{Decimal(settlement.amount_due):.2f} {payment_method} payment "
        "recorded. Exit gate opened and slot released."
    )
    if event:
        event.authorized = True
        event.gate_state = "OPEN"
        event.message = message
    else:
        event = GateEvent(
            parking_area_id=reservation.parking_area_id,
            reservation_id=reservation.id,
            slot_id=reservation.slot_id,
            event_type="EXIT",
            vehicle_number=reservation.vehicle_number,
            authorized=True,
            gate_state="OPEN",
            message=message,
        )
        db.add(event)

    await db.commit()
    await db.refresh(event)
    await broadcast_slot_status(reservation.slot)
    return reservation, settlement, event
