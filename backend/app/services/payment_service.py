import asyncio
import hashlib
import hmac
import logging
from decimal import Decimal
from typing import Any
from uuid import UUID

import razorpay
from fastapi import HTTPException
from razorpay import errors as razorpay_errors
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.config import settings
from app.models.parking_settlement import ParkingSettlement
from app.models.parking_slot import ParkingSlot
from app.models.payment import Payment
from app.models.reservation import Reservation
from app.models.gate_event import GateEvent
from app.schemas.payment_schema import RazorpayOrderCreate, RazorpayPaymentVerify
from app.services.parking_pricing import ADVANCE_FEE, calculate_checkout_balance
from app.services.realtime_service import broadcast_slot_status
from app.utils.helpers import generate_qr_code

logger = logging.getLogger(__name__)


def _credentials() -> tuple[str, str]:
    key_id = settings.RAZORPAY_KEY_ID.strip()
    secret_setting = settings.RAZORPAY_KEY_SECRET
    key_secret = (
        secret_setting.get_secret_value()
        if hasattr(secret_setting, "get_secret_value")
        else str(secret_setting)
    ).strip()
    placeholders = ("replace", "your_key", "your_secret")
    has_placeholder = any(
        marker in value.lower()
        for marker in placeholders
        for value in (key_id, key_secret)
    )
    if not key_id or not key_secret or has_placeholder:
        raise HTTPException(
            status_code=503,
            detail="Razorpay is not configured on the backend",
        )
    return key_id, key_secret


def _razorpay_error_status(error: Exception) -> int:
    message = str(error).lower()
    if (
        "authentication" in message
        or "invalid key" in message
        or "unauthorized" in message
    ):
        # This is a backend gateway-configuration problem, not an expired
        # Smart Parking user token. Returning 401 here made the Flutter API
        # interceptor incorrectly log the user out.
        return 503
    return 502


async def _create_gateway_order(
    key_id: str,
    key_secret: str,
    amount: int,
    currency: str,
    receipt: str,
    reservation_id: UUID,
    user_id: UUID,
    purpose: str,
) -> dict[str, Any]:
    client = razorpay.Client(auth=(key_id, key_secret))
    order_data = {
        "amount": amount,
        "currency": currency,
        "receipt": receipt,
        "notes": {
            "reservation_id": str(reservation_id),
            "user_id": str(user_id),
            "purpose": purpose,
        },
    }

    try:
        return await asyncio.to_thread(client.order.create, data=order_data)
    except razorpay_errors.BadRequestError as error:
        status_code = _razorpay_error_status(error)
        logger.warning("Razorpay rejected order creation: %s", error)
        raise HTTPException(
            status_code=status_code,
            detail=(
                "Razorpay credentials were rejected by the gateway"
                if status_code == 503
                else "Razorpay rejected the order request"
            ),
        ) from error
    except (razorpay_errors.ServerError, razorpay_errors.GatewayError) as error:
        logger.warning("Razorpay gateway unavailable: %s", error)
        raise HTTPException(
            status_code=502,
            detail="Razorpay gateway is temporarily unavailable",
        ) from error
    except Exception as error:
        logger.exception("Unexpected Razorpay order creation failure")
        raise HTTPException(
            status_code=502,
            detail="Razorpay order creation failed",
        ) from error


async def create_razorpay_order(
    db: AsyncSession,
    user_id: UUID,
    data: RazorpayOrderCreate,
) -> dict[str, Any]:
    key_id, key_secret = _credentials()

    result = await db.execute(
        select(Reservation)
        .options(selectinload(Reservation.parking_area))
        .filter(
            Reservation.id == data.reservation_id,
            Reservation.user_id == user_id,
        )
    )
    reservation = result.scalars().first()
    if not reservation:
        raise HTTPException(status_code=404, detail="Reservation not found")

    if data.purpose == "SETTLEMENT":
        return await _create_settlement_order(
            db,
            reservation,
            user_id,
            data,
            key_id,
            key_secret,
        )

    return await _create_advance_order(
        db,
        reservation,
        user_id,
        data,
        key_id,
        key_secret,
    )


async def _create_advance_order(
    db: AsyncSession,
    reservation: Reservation,
    user_id: UUID,
    data: RazorpayOrderCreate,
    key_id: str,
    key_secret: str,
) -> dict[str, Any]:
    if reservation.status != "PAYMENT_PENDING":
        raise HTTPException(status_code=400, detail="Advance payment is not pending")

    expected_amount = int(ADVANCE_FEE * 100)
    if data.amount != expected_amount:
        raise HTTPException(status_code=400, detail="Advance payment must be ₹10")

    expected_currency = (reservation.parking_area.currency or "INR").upper()
    if data.currency.upper() != expected_currency:
        raise HTTPException(
            status_code=400,
            detail="Payment currency does not match the reservation",
        )

    payment_result = await db.execute(
        select(Payment).filter(
            Payment.reservation_id == reservation.id,
            Payment.user_id == user_id,
        )
    )
    payment = payment_result.scalars().first()
    if payment and payment.status == "COMPLETED":
        raise HTTPException(status_code=409, detail="Advance is already paid")
    if (
        payment
        and payment.transaction_id
        and payment.transaction_id.startswith("order_")
        and payment.status in ("CREATED", "PENDING")
    ):
        return {
            "order_id": payment.transaction_id,
            "amount": int(Decimal(payment.amount) * 100),
            "currency": payment.currency,
            "key_id": key_id,
        }

    receipt = data.receipt or f"advance_{reservation.id.hex[:22]}"
    order = await _create_gateway_order(
        key_id,
        key_secret,
        expected_amount,
        expected_currency,
        receipt,
        reservation.id,
        user_id,
        "ADVANCE",
    )

    if not payment:
        payment = Payment(
            reservation_id=reservation.id,
            user_id=user_id,
            amount=ADVANCE_FEE,
            currency=expected_currency,
            method="RAZORPAY_ADVANCE",
        )
        db.add(payment)

    reservation.total_amount = ADVANCE_FEE
    payment.amount = ADVANCE_FEE
    payment.status = "CREATED"
    payment.transaction_id = order["id"]
    await db.commit()

    return {
        "order_id": order["id"],
        "amount": order["amount"],
        "currency": order["currency"],
        "key_id": key_id,
    }


async def _create_settlement_order(
    db: AsyncSession,
    reservation: Reservation,
    user_id: UUID,
    data: RazorpayOrderCreate,
    key_id: str,
    key_secret: str,
) -> dict[str, Any]:
    if reservation.status != "CHECKOUT_PAYMENT_PENDING":
        raise HTTPException(status_code=400, detail="Checkout payment is not pending")

    result = await db.execute(
        select(ParkingSettlement).filter(
            ParkingSettlement.reservation_id == reservation.id,
            ParkingSettlement.user_id == user_id,
        )
    )
    settlement = result.scalars().first()
    if not settlement:
        raise HTTPException(status_code=404, detail="Checkout charge not found")
    if settlement.status == "COMPLETED":
        raise HTTPException(status_code=409, detail="Checkout is already paid")

    expected_amount = int(Decimal(settlement.amount_due) * 100)
    if expected_amount < 100:
        raise HTTPException(status_code=400, detail="No checkout balance is due")
    if data.amount != expected_amount:
        raise HTTPException(
            status_code=400,
            detail="Payment amount does not match the checkout balance",
        )
    if data.currency.upper() != settlement.currency.upper():
        raise HTTPException(
            status_code=400,
            detail="Payment currency does not match the checkout balance",
        )

    if settlement.razorpay_order_id and settlement.status == "CREATED":
        return {
            "order_id": settlement.razorpay_order_id,
            "amount": expected_amount,
            "currency": settlement.currency,
            "key_id": key_id,
        }

    receipt = data.receipt or f"checkout_{reservation.id.hex[:21]}"
    order = await _create_gateway_order(
        key_id,
        key_secret,
        expected_amount,
        settlement.currency,
        receipt,
        reservation.id,
        user_id,
        "SETTLEMENT",
    )

    settlement.status = "CREATED"
    settlement.razorpay_order_id = order["id"]
    await db.commit()

    return {
        "order_id": order["id"],
        "amount": order["amount"],
        "currency": order["currency"],
        "key_id": key_id,
    }


async def verify_razorpay_payment(
    db: AsyncSession,
    user_id: UUID,
    data: RazorpayPaymentVerify,
) -> dict[str, Any]:
    _, key_secret = _credentials()

    message = f"{data.razorpay_order_id}|{data.razorpay_payment_id}".encode()
    generated_signature = hmac.new(
        key_secret.encode(),
        message,
        hashlib.sha256,
    ).hexdigest()
    if not hmac.compare_digest(generated_signature, data.razorpay_signature):
        raise HTTPException(
            status_code=400,
            detail="Payment signature verification failed",
        )

    payment_result = await db.execute(
        select(Payment).filter(
            Payment.user_id == user_id,
            Payment.transaction_id == data.razorpay_order_id,
        )
    )
    advance_payment = payment_result.scalars().first()
    if advance_payment:
        return await _complete_advance_payment(
            db,
            user_id,
            advance_payment,
            data.razorpay_payment_id,
        )

    settlement_result = await db.execute(
        select(ParkingSettlement).filter(
            ParkingSettlement.user_id == user_id,
            ParkingSettlement.razorpay_order_id == data.razorpay_order_id,
        )
    )
    settlement = settlement_result.scalars().first()
    if settlement:
        return await _complete_settlement_payment(
            db,
            user_id,
            settlement,
            data.razorpay_payment_id,
        )

    raise HTTPException(status_code=404, detail="Payment order not found")


async def _complete_advance_payment(
    db: AsyncSession,
    user_id: UUID,
    payment: Payment,
    payment_id: str,
) -> dict[str, Any]:
    result = await db.execute(
        select(Reservation).filter(
            Reservation.id == payment.reservation_id,
            Reservation.user_id == user_id,
        )
    )
    reservation = result.scalars().first()
    if not reservation:
        raise HTTPException(status_code=404, detail="Reservation not found")

    if payment.status != "COMPLETED":
        payment.status = "COMPLETED"
        reservation.advance_paid = True
        if reservation.status == "PAYMENT_PENDING":
            reservation.status = "PENDING"
        if not reservation.qr_code:
            reservation.qr_code = generate_qr_code(
                f"RES-{reservation.id}-{payment_id}"
            )
        settlement_result = await db.execute(
            select(ParkingSettlement).filter(
                ParkingSettlement.reservation_id == reservation.id,
                ParkingSettlement.status != "COMPLETED",
            )
        )
        settlement = settlement_result.scalars().first()
        if settlement:
            settlement.advance_amount = ADVANCE_FEE
            settlement.amount_due = calculate_checkout_balance(
                Decimal(settlement.total_amount),
                advance_paid=True,
            )
            # A late advance can change the final balance. Do not reuse an
            # older Razorpay order that was created for the full amount.
            settlement.status = "PENDING"
            settlement.razorpay_order_id = None
        await db.commit()

    return {
        "success": True,
        "payment_id": payment_id,
        "reservation_id": reservation.id,
    }


async def _complete_settlement_payment(
    db: AsyncSession,
    user_id: UUID,
    settlement: ParkingSettlement,
    payment_id: str,
) -> dict[str, Any]:
    result = await db.execute(
        select(Reservation).filter(
            Reservation.id == settlement.reservation_id,
            Reservation.user_id == user_id,
        )
    )
    reservation = result.scalars().first()
    if not reservation:
        raise HTTPException(status_code=404, detail="Reservation not found")

    if settlement.status != "COMPLETED":
        settlement.status = "COMPLETED"
        settlement.payment_method = "RAZORPAY"
        settlement.razorpay_payment_id = payment_id
        reservation.status = "COMPLETED"

        slot_result = await db.execute(
            select(ParkingSlot).filter(ParkingSlot.id == reservation.slot_id)
        )
        slot = slot_result.scalars().first()
        if slot:
            slot.status = "VACANT"

        gate_event_result = await db.execute(
            select(GateEvent)
            .filter(
                GateEvent.reservation_id == reservation.id,
                GateEvent.event_type == "EXIT",
                GateEvent.authorized.is_(True),
            )
            .order_by(GateEvent.created_at.desc())
        )
        gate_event = gate_event_result.scalars().first()
        if gate_event:
            gate_event.gate_state = "OPEN"
            gate_event.message = (
                "Final payment verified. Exit gate opened and slot released."
            )
        await db.commit()

        if slot:
            try:
                await broadcast_slot_status(slot)
            except Exception:
                logger.exception("Unable to broadcast the released slot")
        # A failed slot broadcast must not skip the gate callback. Require an
        # authorized EXIT scan; a payment alone is not a camera verification.
        if gate_event and reservation.vehicle_number:
            try:
                from app.services.gate_camera_service import gate_camera_service
                await gate_camera_service.open_after_payment(
                    reservation.parking_area_id,
                    reservation.id,
                    reservation.slot_id,
                    reservation.vehicle_number,
                )
            except Exception:
                logger.exception("Payment committed but gate notification failed")

    return {
        "success": True,
        "payment_id": payment_id,
        "reservation_id": reservation.id,
    }
