from datetime import date, datetime
from decimal import Decimal
from typing import Optional
from uuid import UUID

from pydantic import BaseModel


class DailyRevenuePoint(BaseModel):
    date: date
    amount: Decimal


class DashboardStatsResponse(BaseModel):
    total_users: int
    active_users: int
    total_areas: int
    total_slots: int
    available_slots: int
    occupied_slots: int
    reserved_slots: int
    total_reservations: int
    total_revenue: Decimal
    occupancy_rate: float
    revenue_last_7_days: list[DailyRevenuePoint]


class AdminReservationResponse(BaseModel):
    id: UUID
    user_id: UUID
    user_name: str
    slot_id: str
    area_name: str
    vehicle_number: Optional[str] = None
    start_time: datetime
    end_time: Optional[datetime] = None
    status: str
    amount: Decimal
    created_at: datetime


class AdminCameraResponse(BaseModel):
    id: UUID
    name: str
    parking_area_id: UUID
    area_name: str
    floor: Optional[int] = None
    status: str
    is_active: bool
