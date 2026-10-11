from pydantic import BaseModel, Field
from typing import Literal, Optional
from uuid import UUID
from datetime import time, datetime
from decimal import Decimal

class ParkingAreaCreate(BaseModel):
    name: str
    address: str
    latitude: float
    longitude: float
    total_floors: int = 1
    hourly_rate: Decimal
    image_url: Optional[str] = None
    opening_time: time = time(6, 0)
    closing_time: time = time(23, 0)

class ParkingAreaUpdate(BaseModel):
    name: Optional[str] = None
    address: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    total_floors: Optional[int] = None
    hourly_rate: Optional[Decimal] = None
    image_url: Optional[str] = None
    opening_time: Optional[time] = None
    closing_time: Optional[time] = None
    is_active: Optional[bool] = None

class ParkingAreaResponse(BaseModel):
    id: UUID
    name: str
    address: str
    latitude: float
    longitude: float
    total_floors: int
    total_slots: int
    hourly_rate: Decimal
    currency: str
    image_url: Optional[str] = None
    is_active: bool
    opening_time: time
    closing_time: time
    created_at: datetime
    updated_at: Optional[datetime] = None
    available_slots: Optional[int] = 0
    occupied_slots: Optional[int] = 0

    model_config = {"from_attributes": True}

SlotType = Literal["STANDARD", "VIP", "EV", "DISABLED", "WALK_IN"]
SlotStatus = Literal["VACANT", "RESERVED", "OCCUPIED", "MAINTENANCE"]


class ParkingSlotCreate(BaseModel):
    slot_id: str
    parking_area_id: UUID
    floor: int = 1
    slot_type: SlotType = "STANDARD"
    position_x: Optional[int] = None
    position_y: Optional[int] = None

class ParkingSlotUpdate(BaseModel):
    status: Optional[SlotStatus] = None
    slot_type: Optional[SlotType] = None

class ParkingSlotResponse(BaseModel):
    id: UUID
    slot_id: str
    parking_area_id: UUID
    floor: int
    slot_type: str
    status: str
    position_x: Optional[int] = None
    position_y: Optional[int] = None
    created_at: datetime
    updated_at: Optional[datetime] = None

    model_config = {"from_attributes": True}

class FloorSummary(BaseModel):
    floor: int
    total: int
    vacant: int
    occupied: int
    reserved: int
