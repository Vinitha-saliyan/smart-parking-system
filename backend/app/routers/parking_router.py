from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List, Optional
from uuid import UUID
from app.database import get_db
from app.schemas.parking_schema import ParkingAreaResponse, ParkingSlotResponse, FloorSummary
from app.services.parking_service import get_all_areas, get_area_by_id, get_slots_by_area, get_slot_by_id, get_area_summary

router = APIRouter(prefix="/api/v1/parking", tags=["Parking"])

@router.get("/areas", response_model=List[ParkingAreaResponse])
async def list_areas(
    lat: Optional[float] = None,
    lng: Optional[float] = None,
    radius: Optional[float] = None,
    is_active: bool = True,
    db: AsyncSession = Depends(get_db)
):
    areas = await get_all_areas(db, is_active)

    responses = []

    for area in areas:
        slots = await get_slots_by_area(db, area.id)

        available_slots = sum(
            1 for slot in slots if slot.status == "VACANT"
        )

        occupied_slots = sum(
            1 for slot in slots if slot.status == "OCCUPIED"
        )

        area_data = {
            "id": area.id,
            "name": area.name,
            "address": area.address,
            "latitude": area.latitude,
            "longitude": area.longitude,
            "total_floors": area.total_floors,
            "total_slots": area.total_slots,
            "hourly_rate": area.hourly_rate,
            "currency": area.currency,
            "image_url": area.image_url,
            "is_active": area.is_active,
            "opening_time": area.opening_time,
            "closing_time": area.closing_time,
            "created_at": area.created_at,
            "updated_at": area.updated_at,
            "available_slots": available_slots,
            "occupied_slots": occupied_slots,
        }

        responses.append(area_data)

    return responses

@router.get("/areas/{area_id}", response_model=ParkingAreaResponse)
async def get_area(area_id: UUID, db: AsyncSession = Depends(get_db)):
    area = await get_area_by_id(db, area_id)
    if not area:
        raise HTTPException(status_code=404, detail="Area not found")
    # You would compute available/occupied here
    return area

@router.get("/areas/{area_id}/slots", response_model=List[ParkingSlotResponse])
async def get_slots(area_id: UUID, floor: Optional[int] = None, status: Optional[str] = None, db: AsyncSession = Depends(get_db)):
    slots = await get_slots_by_area(db, area_id, floor)
    if status:
        slots = [s for s in slots if s.status == status]
    return slots

@router.get("/areas/{area_id}/summary", response_model=List[FloorSummary])
async def get_summary(area_id: UUID, db: AsyncSession = Depends(get_db)):
    summary = await get_area_summary(db, area_id)
    return summary

@router.get("/slots/{slot_id}", response_model=ParkingSlotResponse)
async def get_slot(slot_id: UUID, db: AsyncSession = Depends(get_db)):
    slot = await get_slot_by_id(db, slot_id)
    if not slot:
        raise HTTPException(status_code=404, detail="Slot not found")
    return slot
