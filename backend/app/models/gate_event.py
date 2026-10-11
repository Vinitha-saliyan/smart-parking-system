import uuid

from sqlalchemy import Boolean, Column, DateTime, Float, ForeignKey, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func

from app.database import Base


class GateEvent(Base):
    """Auditable result of an entry or exit number-plate scan."""

    __tablename__ = "gate_events"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    parking_area_id = Column(
        UUID(as_uuid=True),
        ForeignKey("parking_areas.id"),
        nullable=False,
        index=True,
    )
    reservation_id = Column(
        UUID(as_uuid=True),
        ForeignKey("reservations.id"),
        nullable=True,
        index=True,
    )
    slot_id = Column(
        UUID(as_uuid=True),
        ForeignKey("parking_slots.id"),
        nullable=True,
    )
    event_type = Column(String(10), nullable=False)
    vehicle_number = Column(String(15), nullable=False, index=True)
    ocr_confidence = Column(Float, nullable=True)
    authorized = Column(Boolean, default=False, nullable=False)
    gate_state = Column(String(30), default="CLOSED", nullable=False)
    message = Column(Text, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
