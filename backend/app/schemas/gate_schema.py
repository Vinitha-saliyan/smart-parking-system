from datetime import datetime
from decimal import Decimal
from typing import Literal, Optional
from uuid import UUID

from pydantic import BaseModel, Field, field_validator

from app.utils.vehicle_number import validate_vehicle_number


GateMode = Literal["ENTRY", "EXIT"]


class GateCameraStart(BaseModel):
    mode: GateMode
    parking_area_id: UUID
    camera_index: int = Field(default=0, ge=0, le=10)


class GateModeUpdate(BaseModel):
    mode: GateMode
    parking_area_id: UUID


class GateStatusResponse(BaseModel):
    camera_running: bool
    camera_index: int
    mode: GateMode
    parking_area_id: Optional[UUID] = None
    gate_state: str
    last_vehicle_number: Optional[str] = None
    last_raw_vehicle_number: Optional[str] = None
    last_ocr_confidence: Optional[float] = None
    last_decision_seconds: Optional[float] = None
    last_authorized: Optional[bool] = None
    message: str
    error: Optional[str] = None
    yolo_loaded: bool
    ocr_loaded: bool
    last_reservation_id: Optional[UUID] = None
    last_slot_id: Optional[UUID] = None
    last_slot_number: Optional[str] = None
    last_booking_type: Optional[str] = None
    last_amount_due: Optional[Decimal] = None
    last_advance_paid: Optional[bool] = None
    manual_payment_required: bool = False


class WalkInAdmissionRequest(BaseModel):
    parking_area_id: UUID
    slot_id: UUID
    vehicle_number: str

    @field_validator("vehicle_number")
    @classmethod
    def normalize_number(cls, value: str) -> str:
        return validate_vehicle_number(value)


class WalkInPaymentRequest(BaseModel):
    method: Literal["CASH", "UPI"]


class GateEventResponse(BaseModel):
    id: UUID
    parking_area_id: UUID
    reservation_id: Optional[UUID] = None
    slot_id: Optional[UUID] = None
    slot_number: Optional[str] = None
    event_type: str
    vehicle_number: str
    ocr_confidence: Optional[float] = None
    authorized: bool
    gate_state: str
    message: str
    created_at: datetime
