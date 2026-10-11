from pydantic import BaseModel
from typing import Optional
from uuid import UUID
from datetime import datetime

class CameraCreate(BaseModel):
    name: str
    stream_url: str
    camera_type: str = "IP"
    parking_area_id: UUID
    floor: Optional[int] = None

class CameraUpdate(BaseModel):
    name: Optional[str] = None
    stream_url: Optional[str] = None
    camera_type: Optional[str] = None
    parking_area_id: Optional[UUID] = None
    floor: Optional[int] = None
    status: Optional[str] = None
    is_active: Optional[bool] = None

class CameraResponse(BaseModel):
    id: UUID
    name: str
    stream_url: str
    camera_type: str
    parking_area_id: UUID
    floor: Optional[int] = None
    status: str
    is_active: bool
    created_at: datetime

    model_config = {"from_attributes": True}
