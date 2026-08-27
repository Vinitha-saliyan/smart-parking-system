import asyncio
import logging
from sqlalchemy import select
from app.database import AsyncSessionLocal, init_db
from app.models.user import User
from app.models.parking_area import ParkingArea
from app.models.parking_slot import ParkingSlot
from app.services.auth_service import hash_password
from datetime import time
from decimal import Decimal

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def seed_data():
    await init_db()
    
    async with AsyncSessionLocal() as db:
        # Create admin user
        result = await db.execute(select(User).filter(User.email == "admin@smartparking.com"))
        admin = result.scalars().first()
        if not admin:
            admin = User(
                email="admin@smartparking.com",
                hashed_password=hash_password("Admin@123"),
                full_name="System Admin",
                role="ADMIN",
                is_active=True,
                is_verified=True
            )
            db.add(admin)
            await db.commit()
            await db.refresh(admin)
            logger.info("Admin user created")
        else:
            admin.hashed_password = hash_password("Admin@123")
            admin.full_name = "System Admin"
            admin.role = "ADMIN"
            admin.is_active = True
            admin.is_verified = True
            await db.commit()
            logger.info("Admin user reset and verified")
        
        # Create Parking Area
        result = await db.execute(select(ParkingArea).filter(ParkingArea.name == "Smart Park Central"))
        area = result.scalars().first()
        if not area:
            area = ParkingArea(
                name="Smart Park Central",
                address="123 Smart City Blvd",
                latitude=28.6139,
                longitude=77.2090,
                total_floors=1,
                total_slots=20,
                hourly_rate=Decimal("20.00"),
                currency="INR",
                opening_time=time(6, 0),
                closing_time=time(23, 0)
            )
            db.add(area)
            await db.commit()
            await db.refresh(area)
            logger.info("Parking area created")
            
            # Create Slots
            slots_data = []
            
            # Row A (A01-A10): y=0, x=0-9
            for i in range(1, 11):
                slots_data.append(ParkingSlot(slot_id=f"A{i:02d}", parking_area_id=area.id, floor=1, slot_type="STANDARD", position_x=i-1, position_y=0, status="VACANT"))
            
            # Row B (B01-B05): y=1, x=0-4
            for i in range(1, 6):
                slots_data.append(ParkingSlot(slot_id=f"B{i:02d}", parking_area_id=area.id, floor=1, slot_type="STANDARD", position_x=i-1, position_y=1, status="VACANT"))
            
            # Row C (C01-C03): y=2, x=0-2, type=VIP
            for i in range(1, 4):
                slots_data.append(ParkingSlot(slot_id=f"C{i:02d}", parking_area_id=area.id, floor=1, slot_type="VIP", position_x=i-1, position_y=2, status="VACANT"))
                
            # Row D (D01): y=3, x=0, type=EV
            slots_data.append(ParkingSlot(slot_id="D01", parking_area_id=area.id, floor=1, slot_type="EV", position_x=0, position_y=3, status="VACANT"))
            
            # Row E (E01): y=3, x=1, type=DISABLED
            slots_data.append(ParkingSlot(slot_id="E01", parking_area_id=area.id, floor=1, slot_type="DISABLED", position_x=1, position_y=3, status="VACANT"))

            for slot in slots_data:
                if slot.slot_id in ["A03", "A07", "B02"]:
                    slot.status = "OCCUPIED"
                elif slot.slot_id == "A05":
                    slot.status = "RESERVED"
                db.add(slot)
                
            await db.commit()
            logger.info("Parking slots created and initialized")

if __name__ == "__main__":
    asyncio.run(seed_data())
