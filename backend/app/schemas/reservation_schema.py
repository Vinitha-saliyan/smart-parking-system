from pydantic import BaseModel
from typing import Optional
from uuid import UUID
from datetime import datetime
from decimal import Decimal
from app.schemas.parking_schema import ParkingSlotResponse

class ReservationCreate(BaseModel):
    slot_id: UUID
    parking_area_id: UUID
    start_time: datetime
    end_time: Optional[datetime] = None

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
    qr_code: Optional[str] = None
    total_amount: Optional[Decimal] = None
    created_at: datetime
    updated_at: Optional[datetime] = None
    slot: Optional[ParkingSlotResponse] = None
    parking_area_name: Optional[str] = None

    model_config = {"from_attributes": True}
