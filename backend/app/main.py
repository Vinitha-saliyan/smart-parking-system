from fastapi import FastAPI
from contextlib import asynccontextmanager
import logging
import asyncio

from app.database import AsyncSessionLocal, init_db
from app.utils.redis_client import redis_client
from app.config import settings
from app.middleware.cors import setup_cors
from app.routers import auth_router, parking_router, reservation_router, admin_router, notification_router, payment_router, websocket_router, detection_router, gate_router
from app.services.reservation_service import expire_pending_reservations
from app.services.gate_camera_service import gate_camera_service
from app.services.walk_in_service import ensure_walk_in_resources

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


async def reservation_expiry_worker():
    while True:
        try:
            async with AsyncSessionLocal() as db:
                await expire_pending_reservations(db)
        except asyncio.CancelledError:
            raise
        except Exception:
            logger.exception("Failed to expire pending reservations")
        await asyncio.sleep(30)

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Initializing database...")
    await init_db()
    await ensure_walk_in_resources()
    
    logger.info("Connecting to Redis...")
    await redis_client.connect(settings.REDIS_URL)

    expiry_task = asyncio.create_task(reservation_expiry_worker())
    
    logger.info("Application startup complete.")
    yield

    expiry_task.cancel()
    try:
        await expiry_task
    except asyncio.CancelledError:
        pass

    logger.info("Application shutdown.")
    await gate_camera_service.stop()

app = FastAPI(title="AI Smart Parking System API", lifespan=lifespan)

setup_cors(app)

app.include_router(auth_router.router)
app.include_router(parking_router.router)
app.include_router(reservation_router.router)
app.include_router(admin_router.router)
app.include_router(notification_router.router)
app.include_router(payment_router.router)
app.include_router(websocket_router.router)
app.include_router(detection_router.router)
app.include_router(gate_router.router)

@app.get("/")
async def root():
    return {"message": "Welcome to AI Smart Parking System API"}

@app.get("/health")
async def health_check():
    return {"status": "ok"}
