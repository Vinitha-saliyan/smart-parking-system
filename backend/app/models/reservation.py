import uuid
from sqlalchemy import Column, String, DateTime, Numeric, Text, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database import Base

class Reservation(Base):
    """Reservation model."""
    __tablename__ = "reservations"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    slot_id = Column(UUID(as_uuid=True), ForeignKey("parking_slots.id"))
    parking_area_id = Column(UUID(as_uuid=True), ForeignKey("parking_areas.id"))
    start_time = Column(DateTime(timezone=True), nullable=False)
    end_time = Column(DateTime(timezone=True), nullable=True)
    actual_check_in = Column(DateTime(timezone=True), nullable=True)
    actual_check_out = Column(DateTime(timezone=True), nullable=True)
    status = Column(String(20), default="PENDING")
    qr_code = Column(Text, nullable=True)
    total_amount = Column(Numeric(10, 2), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    user = relationship("User", back_populates="reservations")
    slot = relationship("ParkingSlot", back_populates="reservations")
    parking_area = relationship("ParkingArea", back_populates="reservations")
    payment = relationship("Payment", back_populates="reservation", uselist=False)
