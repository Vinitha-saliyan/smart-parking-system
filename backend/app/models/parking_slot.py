import uuid
from sqlalchemy import Column, String, Integer, DateTime, UniqueConstraint, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database import Base

class ParkingSlot(Base):
    """ParkingSlot model."""
    __tablename__ = "parking_slots"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    slot_id = Column(String(10), nullable=False)
    parking_area_id = Column(UUID(as_uuid=True), ForeignKey("parking_areas.id"))
    floor = Column(Integer, default=1)
    slot_type = Column(String(20), default="STANDARD")
    status = Column(String(20), default="VACANT")
    position_x = Column(Integer, nullable=True)
    position_y = Column(Integer, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    __table_args__ = (UniqueConstraint("parking_area_id", "slot_id", name="_area_slot_uc"),)

    parking_area = relationship("ParkingArea", back_populates="slots")
    reservations = relationship("Reservation", back_populates="slot")
