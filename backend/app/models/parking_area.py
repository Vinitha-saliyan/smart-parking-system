import uuid
from sqlalchemy import Column, String, Integer, Float, Boolean, DateTime, Time, Numeric, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database import Base
from datetime import time

class ParkingArea(Base):
    """ParkingArea model."""
    __tablename__ = "parking_areas"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(255), nullable=False)
    address = Column(Text, nullable=False)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    total_floors = Column(Integer, default=1)
    total_slots = Column(Integer, default=0)
    hourly_rate = Column(Numeric(10, 2), nullable=False)
    currency = Column(String(3), default="INR")
    image_url = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True)
    opening_time = Column(Time, default=time(6, 0))
    closing_time = Column(Time, default=time(23, 0))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    slots = relationship("ParkingSlot", back_populates="parking_area")
    cameras = relationship("Camera", back_populates="parking_area")
    reservations = relationship("Reservation", back_populates="parking_area")
