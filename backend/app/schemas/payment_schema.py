from pydantic import BaseModel, Field
from typing import Literal, Optional
from uuid import UUID
from datetime import datetime
from decimal import Decimal

class PaymentCreate(BaseModel):
    reservation_id: UUID
    amount: Decimal
    method: str

class PaymentResponse(BaseModel):
    id: UUID
    reservation_id: UUID
    user_id: UUID
    amount: Decimal
    currency: str
    method: Optional[str] = None
    status: str
    transaction_id: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}


class RazorpayOrderCreate(BaseModel):
    reservation_id: UUID
    amount: int = Field(ge=100, description="Amount in paise")
    currency: str = Field(default="INR", min_length=3, max_length=3)
    receipt: Optional[str] = Field(default=None, max_length=40)
    purpose: Literal["ADVANCE", "SETTLEMENT"] = "ADVANCE"


class RazorpayOrderResponse(BaseModel):
    order_id: str
    amount: int
    currency: str
    key_id: str


class RazorpayPaymentVerify(BaseModel):
    razorpay_payment_id: str = Field(min_length=1)
    razorpay_order_id: str = Field(min_length=1)
    razorpay_signature: str = Field(min_length=1)


class RazorpayVerificationResponse(BaseModel):
    success: bool
    payment_id: str
    reservation_id: UUID
