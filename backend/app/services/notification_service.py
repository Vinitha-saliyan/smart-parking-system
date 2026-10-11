from typing import List, Optional, Dict, Any
from uuid import UUID
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.models.notification import Notification

import logging
logger = logging.getLogger(__name__)

async def create_notification(db: AsyncSession, user_id: UUID, title: str, body: str, type: str, data: Optional[Dict[str, Any]] = None) -> Notification:
    notif = Notification(
        user_id=user_id,
        title=title,
        body=body,
        type=type,
        data=data
    )
    db.add(notif)
    await db.commit()
    await db.refresh(notif)
    return notif

async def get_user_notifications(db: AsyncSession, user_id: UUID, unread_only: bool = False) -> List[Notification]:
    query = select(Notification).filter(Notification.user_id == user_id)
    if unread_only:
        query = query.filter(Notification.is_read == False)
    query = query.order_by(Notification.created_at.desc())
    result = await db.execute(query)
    return list(result.scalars().all())

async def mark_as_read(db: AsyncSession, notification_id: UUID):
    result = await db.execute(select(Notification).filter(Notification.id == notification_id))
    notif = result.scalars().first()
    if notif:
        notif.is_read = True
        await db.commit()

async def mark_all_as_read(db: AsyncSession, user_id: UUID):
    result = await db.execute(select(Notification).filter(Notification.user_id == user_id, Notification.is_read == False))
    notifs = result.scalars().all()
    for notif in notifs:
        notif.is_read = True
    await db.commit()

async def send_push_notification(user_id: UUID, title: str, body: str):
    # Mocking push notification via Firebase or similar
    logger.info(f"Sending push notification to user {user_id}: {title} - {body}")
    pass
