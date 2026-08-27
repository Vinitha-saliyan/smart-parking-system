from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List, Optional
from uuid import UUID
from app.database import get_db
from app.models.user import User
from sqlalchemy.orm import selectinload
from app.models.reservation import Reservation
from app.schemas.reservation_schema import ReservationCreate, ReservationResponse
from app.services.auth_service import get_current_user
from app.services.reservation_service import create_reservation, cancel_reservation, check_in, check_out, get_user_reservations, get_active_reservation

router = APIRouter(prefix="/api/v1/reservations", tags=["Reservations"])

@router.post("/", response_model=ReservationResponse)
async def create_new_reservation(data: ReservationCreate, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    return await create_reservation(db, current_user.id, data)

@router.get("/", response_model=List[ReservationResponse])
async def list_reservations(status: Optional[str] = None, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    return await get_user_reservations(db, current_user.id, status)

@router.get("/active", response_model=Optional[ReservationResponse])
async def get_active(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    return await get_active_reservation(db, current_user.id)
@router.get("/{reservation_id}", response_model=ReservationResponse)
async def get_reservation(
    reservation_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(Reservation)
        .options(selectinload(Reservation.slot))
        .filter(
            Reservation.id == reservation_id,
            Reservation.user_id == current_user.id
        )
    )

    res = result.scalars().first()

    if not res:
        raise HTTPException(
            status_code=404,
            detail="Reservation not found"
        )

    return res

@router.put("/{reservation_id}/cancel", response_model=ReservationResponse)
async def cancel(reservation_id: UUID, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    return await cancel_reservation(db, reservation_id, current_user.id)

@router.put("/{reservation_id}/check-in", response_model=ReservationResponse)
async def perform_check_in(reservation_id: UUID, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    # In reality, this might be triggered by hardware, not directly by user, but let's allow it for simulation
    return await check_in(db, reservation_id, current_user.id)

@router.put("/{reservation_id}/check-out", response_model=ReservationResponse)
async def perform_check_out(reservation_id: UUID, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    return await check_out(db, reservation_id, current_user.id)
