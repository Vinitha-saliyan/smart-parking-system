from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List, Dict, Any
from uuid import UUID
from app.database import get_db
from app.models.user import User
from app.services.auth_service import get_current_user, require_role
from app.services.notification_service import get_user_notifications, mark_as_read, mark_all_as_read, create_notification

router = APIRouter(prefix="/api/v1/notifications", tags=["Notifications"])

@router.get("/")
async def list_notifications(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    return await get_user_notifications(db, current_user.id)

@router.put("/{id}/read")
async def read_notification(id: UUID, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    await mark_as_read(db, id)
    return {"message": "Marked as read"}

@router.put("/read-all")
async def read_all(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    await mark_all_as_read(db, current_user.id)
    return {"message": "All marked as read"}

@router.post("/broadcast", dependencies=[Depends(require_role("ADMIN"))])
async def broadcast(title: str, body: str, type: str = "ANNOUNCEMENT", db: AsyncSession = Depends(get_db)):
    from sqlalchemy import select
    result = await db.execute(select(User))
    users = result.scalars().all()
    for user in users:
        await create_notification(db, user.id, title, body, type)
    return {"message": f"Broadcasted to {len(users)} users"}
