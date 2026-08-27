from typing import List, Dict, Any, Optional
from uuid import UUID
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, update, delete, case
from app.models.parking_area import ParkingArea
from app.models.parking_slot import ParkingSlot
from app.schemas.parking_schema import ParkingAreaCreate, ParkingAreaUpdate, ParkingSlotCreate

async def get_all_areas(db: AsyncSession, is_active: Optional[bool] = True) -> List[ParkingArea]:
    query = select(ParkingArea)
    if is_active is not None:
        query = query.filter(ParkingArea.is_active == is_active)
    query = query.order_by(ParkingArea.name)
    result = await db.execute(query)
    return list(result.scalars().all())

async def get_area_by_id(db: AsyncSession, area_id: UUID) -> Optional[ParkingArea]:
    result = await db.execute(select(ParkingArea).filter(ParkingArea.id == area_id))
    return result.scalars().first()

async def create_area(db: AsyncSession, area_data: ParkingAreaCreate) -> ParkingArea:
    new_area = ParkingArea(**area_data.model_dump())
    db.add(new_area)
    await db.commit()
    await db.refresh(new_area)
    return new_area

async def update_area(db: AsyncSession, area_id: UUID, data: ParkingAreaUpdate) -> Optional[ParkingArea]:
    area = await get_area_by_id(db, area_id)
    if not area:
        return None
    for key, value in data.model_dump(exclude_unset=True).items():
        setattr(area, key, value)
    await db.commit()
    await db.refresh(area)
    return area

async def delete_area(db: AsyncSession, area_id: UUID):
    area = await get_area_by_id(db, area_id)
    if area:
        await db.delete(area)
        await db.commit()

async def get_slots_by_area(db: AsyncSession, area_id: UUID, floor: Optional[int] = None) -> List[ParkingSlot]:
    query = select(ParkingSlot).filter(ParkingSlot.parking_area_id == area_id)
    if floor is not None:
        query = query.filter(ParkingSlot.floor == floor)
    result = await db.execute(query)
    return list(result.scalars().all())

async def get_slot_by_id(db: AsyncSession, slot_id: UUID) -> Optional[ParkingSlot]:
    result = await db.execute(select(ParkingSlot).filter(ParkingSlot.id == slot_id))
    return result.scalars().first()

async def create_slot(db: AsyncSession, slot_data: ParkingSlotCreate) -> ParkingSlot:
    new_slot = ParkingSlot(**slot_data.model_dump())
    db.add(new_slot)
    await db.commit()
    await db.refresh(new_slot)
    return new_slot

async def update_slot_status(db: AsyncSession, slot_id: UUID, status: str) -> Optional[ParkingSlot]:
    slot = await get_slot_by_id(db, slot_id)
    if not slot:
        return None
    slot.status = status
    await db.commit()
    await db.refresh(slot)
    return slot

async def get_area_summary(db: AsyncSession, area_id: UUID) -> List[Dict[str, Any]]:
    query = (
        select(
            ParkingSlot.floor,
            func.count(ParkingSlot.id).label("total"),
            func.sum(
                case(
                    (ParkingSlot.status == "VACANT", 1),
                    else_=0
                )
            ).label("vacant"),
            func.sum(
                case(
                    (ParkingSlot.status == "OCCUPIED", 1),
                    else_=0
                )
            ).label("occupied"),
            func.sum(
                case(
                    (ParkingSlot.status == "RESERVED", 1),
                    else_=0
                )
            ).label("reserved"),
        )
        .where(ParkingSlot.parking_area_id == area_id)
        .group_by(ParkingSlot.floor)
        .order_by(ParkingSlot.floor)
    )

    result = await db.execute(query)

    summary = []

    for row in result:
        summary.append({
            "floor": row.floor,
            "total": row.total,
            "vacant": row.vacant or 0,
            "occupied": row.occupied or 0,
            "reserved": row.reserved or 0,
        })

    return summary
async def bulk_create_slots(db: AsyncSession, area_id: UUID, floor: int, prefix: str, count: int) -> List[ParkingSlot]:
    slots = []
    for i in range(1, count + 1):
        slot_id = f"{prefix}{i:02d}"
        new_slot = ParkingSlot(
            slot_id=slot_id,
            parking_area_id=area_id,
            floor=floor,
            slot_type="STANDARD"
        )
        db.add(new_slot)
        slots.append(new_slot)
    await db.commit()
    for slot in slots:
        await db.refresh(slot)
    return slots
