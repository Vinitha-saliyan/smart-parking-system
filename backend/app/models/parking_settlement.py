import uuid

from sqlalchemy import Column, DateTime, ForeignKey, Numeric, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func

from app.database import Base


class ParkingSettlement(Base):
    """Final parking charge after the vehicle checks out."""

    __tablename__ = "parking_settlements"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    reservation_id = Column(
        UUID(as_uuid=True),
        ForeignKey("reservations.id"),
        nullable=False,
        unique=True,
        index=True,
    )
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    total_amount = Column(Numeric(10, 2), nullable=False)
    advance_amount = Column(Numeric(10, 2), nullable=False)
    amount_due = Column(Numeric(10, 2), nullable=False)
    currency = Column(String(3), default="INR", nullable=False)
    status = Column(String(20), default="PENDING", nullable=False)
    razorpay_order_id = Column(String(255), nullable=True, unique=True)
    razorpay_payment_id = Column(String(255), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )
