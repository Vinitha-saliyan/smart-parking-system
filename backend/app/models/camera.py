import uuid
from sqlalchemy import Column, String, Integer, Boolean, DateTime, Text, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.database import Base

class Camera(Base):
    """Camera model."""
    __tablename__ = "cameras"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(255), nullable=False)
    stream_url = Column(Text, nullable=False)
    camera_type = Column(String(20), default="IP")
    parking_area_id = Column(UUID(as_uuid=True), ForeignKey("parking_areas.id"))
    floor = Column(Integer, nullable=True)
    status = Column(String(20), default="OFFLINE")
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    parking_area = relationship("ParkingArea", back_populates="cameras")
