from pydantic import BaseModel, field_validator
from typing import Optional
from uuid import UUID
from datetime import datetime
from decimal import Decimal
from app.schemas.parking_schema import ParkingSlotResponse
from app.utils.vehicle_number import validate_vehicle_number

class ReservationCreate(BaseModel):
    slot_id: UUID
    parking_area_id: UUID
    start_time: datetime
    end_time: Optional[datetime] = None
    vehicle_number: str

    @field_validator("vehicle_number")
    @classmethod
    def normalize_number(cls, value: str) -> str:
        return validate_vehicle_number(value)

class ReservationUpdate(BaseModel):
    status: str

class ReservationResponse(BaseModel):
    id: UUID
    user_id: UUID
    slot_id: UUID
    parking_area_id: UUID
    start_time: datetime
    end_time: Optional[datetime] = None
    actual_check_in: Optional[datetime] = None
    actual_check_out: Optional[datetime] = None
    status: str
    booking_type: str = "PREBOOKED"
    advance_paid: bool = False
    vehicle_number: Optional[str] = None
    qr_code: Optional[str] = None
    total_amount: Optional[Decimal] = None
    created_at: datetime
    updated_at: Optional[datetime] = None
    slot: Optional[ParkingSlotResponse] = None
    parking_area_name: Optional[str] = None

    model_config = {"from_attributes": True}
