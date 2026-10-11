from datetime import datetime, timedelta, timezone
import logging
from typing import List, Optional
from uuid import UUID

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.config import settings
from app.models.parking_area import ParkingArea
from app.models.parking_settlement import ParkingSettlement
from app.models.parking_slot import ParkingSlot
from app.models.reservation import Reservation
from app.schemas.reservation_schema import ReservationCreate
from app.services.parking_pricing import (
    ADVANCE_FEE,
    calculate_checkout_balance,
    calculate_parking_total,
)
from app.services.realtime_service import broadcast_slot_status


logger = logging.getLogger(__name__)


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


async def _release_slot(
    db: AsyncSession,
    slot_id: UUID,
) -> Optional[ParkingSlot]:
    slot_result = await db.execute(
        select(ParkingSlot).filter(ParkingSlot.id == slot_id)
    )
    slot = slot_result.scalars().first()
    if slot:
        slot.status = "VACANT"
    return slot


async def _safe_broadcast_slot_status(slot: ParkingSlot) -> None:
    """Broadcast after commit without turning a saved DB change into HTTP 500."""
    try:
        await broadcast_slot_status(slot)
    except Exception:
        logger.exception(
            "Unable to broadcast slot %s status %s",
            slot.slot_id,
            slot.status,
        )


async def create_reservation(
    db: AsyncSession,
    user_id: UUID,
    data: ReservationCreate,
) -> Reservation:
    result = await db.execute(
        select(ParkingSlot)
        .filter(ParkingSlot.id == data.slot_id)
        .with_for_update()
    )
    slot = result.scalars().first()

    if not slot or slot.status != "VACANT":
        raise HTTPException(status_code=400, detail="Slot is not available")
    if slot.slot_type == "WALK_IN" or slot.slot_id in {"W01", "W02"}:
        raise HTTPException(
            status_code=400,
            detail="W01 and W02 are reserved for admin-assigned walk-ins",
        )

    area_result = await db.execute(
        select(ParkingArea).filter(ParkingArea.id == data.parking_area_id)
    )
    area = area_result.scalars().first()
    if not area or slot.parking_area_id != area.id:
        raise HTTPException(status_code=400, detail="Invalid parking area")

    existing_result = await db.execute(
        select(Reservation.id).filter(
            Reservation.parking_area_id == data.parking_area_id,
            Reservation.vehicle_number == data.vehicle_number,
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
            detail="This vehicle already has an active parking reservation",
        )

    start_time = _as_utc(data.start_time)
    end_time = (
        _as_utc(data.end_time)
        if data.end_time is not None
        else start_time + timedelta(hours=1)
    )
    new_reservation = Reservation(
        user_id=user_id,
        slot_id=data.slot_id,
        parking_area_id=data.parking_area_id,
        start_time=start_time,
        end_time=end_time,
        status="PAYMENT_PENDING",
        booking_type="PREBOOKED",
        advance_paid=False,
        vehicle_number=data.vehicle_number,
        qr_code=None,
        total_amount=ADVANCE_FEE,
    )

    slot.status = "RESERVED"
    db.add(new_reservation)
    await db.commit()
    await _safe_broadcast_slot_status(slot)

    result = await db.execute(
        select(Reservation)
        .options(selectinload(Reservation.slot))
        .filter(Reservation.id == new_reservation.id)
    )
    return result.scalars().first()


async def cancel_reservation(
    db: AsyncSession,
    reservation_id: UUID,
    user_id: UUID,
) -> Reservation:
    result = await db.execute(
        select(Reservation)
        .options(selectinload(Reservation.slot))
        .filter(
            Reservation.id == reservation_id,
            Reservation.user_id == user_id,
        )
        .with_for_update()
    )
    reservation = result.scalars().first()

    if not reservation:
        raise HTTPException(status_code=404, detail="Reservation not found")
    if reservation.status not in ("PAYMENT_PENDING", "PENDING"):
        raise HTTPException(
            status_code=400,
            detail=(
                "Only a reservation that has not checked in can be cancelled. "
                f"Current status: {reservation.status}"
            ),
        )

    # The ₹10 advance is intentionally non-refundable.
    reservation.status = "CANCELLED"
    released_slot = await _release_slot(db, reservation.slot_id)
    await db.commit()
    if released_slot:
        await _safe_broadcast_slot_status(released_slot)

    result = await db.execute(
        select(Reservation)
        .options(selectinload(Reservation.slot))
        .filter(Reservation.id == reservation_id)
    )
    return result.scalars().first()


async def check_in(
    db: AsyncSession,
    reservation_id: UUID,
    user_id: UUID,
) -> Reservation:
    result = await db.execute(
        select(Reservation)
        .options(selectinload(Reservation.slot))
        .filter(
            Reservation.id == reservation_id,
            Reservation.user_id == user_id,
        )
        .with_for_update()
    )
    reservation = result.scalars().first()

    if not reservation or reservation.status not in {
        "PAYMENT_PENDING",
        "PENDING",
    }:
        raise HTTPException(status_code=400, detail="Invalid reservation for check-in")

    slot_result = await db.execute(
        select(ParkingSlot)
        .filter(ParkingSlot.id == reservation.slot_id)
        .with_for_update()
    )
    slot = slot_result.scalars().first()
    if (
        slot is None
        or slot.parking_area_id != reservation.parking_area_id
        or slot.status != "RESERVED"
    ):
        raise HTTPException(
            status_code=409,
            detail="The assigned parking slot is no longer available",
        )

    now = datetime.now(timezone.utc)
    created_at = _as_utc(reservation.created_at)
    entry_deadline = created_at + timedelta(
        minutes=settings.RESERVATION_TIMEOUT_MINUTES
    )
    if now >= entry_deadline:
        reservation.status = "EXPIRED"
        released_slot = await _release_slot(db, reservation.slot_id)
        await db.commit()
        if released_slot:
            await _safe_broadcast_slot_status(released_slot)
        raise HTTPException(
            status_code=400,
            detail="The 30-minute entry window has expired",
        )

    reservation.status = "ACTIVE"
    reservation.actual_check_in = now

    slot.status = "OCCUPIED"

    await db.commit()
    await _safe_broadcast_slot_status(slot)

    result = await db.execute(
        select(Reservation)
        .options(selectinload(Reservation.slot))
        .filter(Reservation.id == reservation_id)
    )
    return result.scalars().first()


async def check_out(
    db: AsyncSession,
    reservation_id: UUID,
    user_id: UUID,
) -> Reservation:
    result = await db.execute(
        select(Reservation)
        .options(
            selectinload(Reservation.slot),
            selectinload(Reservation.parking_area),
        )
        .filter(
            Reservation.id == reservation_id,
            Reservation.user_id == user_id,
        )
    )
    reservation = result.scalars().first()

    if not reservation:
        raise HTTPException(status_code=404, detail="Reservation not found")
    if reservation.status == "CHECKOUT_PAYMENT_PENDING":
        return reservation
    if reservation.status != "ACTIVE" or not reservation.actual_check_in:
        raise HTTPException(status_code=400, detail="Invalid reservation for check-out")

    checkout_time = datetime.now(timezone.utc)
    duration = checkout_time - _as_utc(reservation.actual_check_in)
    total_amount = calculate_parking_total(duration.total_seconds())
    advance_paid = bool(reservation.advance_paid)
    advance_amount = ADVANCE_FEE if advance_paid else 0
    amount_due = calculate_checkout_balance(
        total_amount,
        advance_paid=advance_paid,
    )

    reservation.actual_check_out = checkout_time
    reservation.total_amount = total_amount
    reservation.status = "CHECKOUT_PAYMENT_PENDING"

    settlement_result = await db.execute(
        select(ParkingSettlement).filter(
            ParkingSettlement.reservation_id == reservation.id,
            ParkingSettlement.user_id == user_id,
        )
    )
    settlement = settlement_result.scalars().first()
    if not settlement:
        settlement = ParkingSettlement(
            reservation_id=reservation.id,
            user_id=user_id,
            total_amount=total_amount,
            advance_amount=advance_amount,
            amount_due=amount_due,
            currency=(reservation.parking_area.currency or "INR").upper(),
            status="PENDING",
        )
        db.add(settlement)
    else:
        settlement.total_amount = total_amount
        settlement.advance_amount = advance_amount
        settlement.amount_due = amount_due
        settlement.status = "PENDING"
        settlement.payment_method = None
        settlement.recorded_by = None
        settlement.razorpay_order_id = None
        settlement.razorpay_payment_id = None

    # Keep the slot occupied until the final Razorpay signature is verified.
    await db.commit()

    result = await db.execute(
        select(Reservation)
        .options(selectinload(Reservation.slot))
        .filter(Reservation.id == reservation_id)
    )
    return result.scalars().first()


async def get_user_reservations(
    db: AsyncSession,
    user_id: UUID,
    status: Optional[str] = None,
) -> List[Reservation]:
    query = select(Reservation).filter(Reservation.user_id == user_id)
    if status:
        query = query.filter(Reservation.status == status)

    query = query.options(selectinload(Reservation.slot))
    result = await db.execute(query)
    return list(result.scalars().all())


async def get_active_reservation(
    db: AsyncSession,
    user_id: UUID,
) -> Optional[Reservation]:
    query = (
        select(Reservation)
        .options(selectinload(Reservation.slot))
        .filter(
            Reservation.user_id == user_id,
            Reservation.status.in_(
                [
                    "PAYMENT_PENDING",
                    "PENDING",
                    "ACTIVE",
                    "CHECKOUT_PAYMENT_PENDING",
                ]
            ),
        )
        .order_by(Reservation.created_at.desc())
    )
    result = await db.execute(query)
    return result.scalars().first()


async def expire_pending_reservations(db: AsyncSession) -> None:
    timeout_threshold = datetime.now(timezone.utc) - timedelta(
        minutes=settings.RESERVATION_TIMEOUT_MINUTES
    )
    query = select(Reservation).filter(
        Reservation.status.in_(["PAYMENT_PENDING", "PENDING"]),
        Reservation.created_at < timeout_threshold,
    )
    result = await db.execute(query)

    released_slots: list[ParkingSlot] = []
    for reservation in result.scalars().all():
        reservation.status = "EXPIRED"
        slot = await _release_slot(db, reservation.slot_id)
        if slot:
            released_slots.append(slot)

    await db.commit()
    for slot in released_slots:
        await _safe_broadcast_slot_status(slot)
