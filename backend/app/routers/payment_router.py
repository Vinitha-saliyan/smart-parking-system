from typing import Any

from fastapi import APIRouter, Depends, HTTPException
from pydantic import ValidationError
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.user import User
from app.schemas.payment_schema import (
    RazorpayOrderCreate,
    RazorpayOrderResponse,
    RazorpayPaymentVerify,
    RazorpayVerificationResponse,
)
from app.services.auth_service import get_current_user
from app.services.payment_service import create_razorpay_order, verify_razorpay_payment


router = APIRouter(prefix="/api/v1/payments", tags=["Payments"])


@router.post("/create-order", response_model=RazorpayOrderResponse)
async def create_order(
    data: RazorpayOrderCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await create_razorpay_order(db, current_user.id, data)


@router.post("/verify-payment", response_model=RazorpayVerificationResponse)
async def verify_payment(
    payload: dict[str, Any],
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        data = RazorpayPaymentVerify.model_validate(payload)
    except ValidationError as error:
        raise HTTPException(status_code=400, detail="Missing or invalid payment fields") from error
    return await verify_razorpay_payment(db, current_user.id, data)
