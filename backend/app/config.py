from typing import List

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings."""

    DATABASE_URL: str = (
        "postgresql+asyncpg://parking_admin:"
        "parking_secret_2024@localhost:5432/smart_parking"
    )

    REDIS_URL: str = "redis://localhost:6379"

    SECRET_KEY: str = "supersecretkey"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    YOLO_MODEL_PATH: str = "yolo11n.pt"
    YOLO_CONFIDENCE_THRESHOLD: float = 0.5
    YOLO_IOU_THRESHOLD: float = 0.45

    # Recorded-video detection settings. The model is loaded lazily so a YOLO
    # problem never prevents authentication, reservations, or payments from
    # starting.
    YOLO_VIDEO_SAMPLE_FPS: float = 2.0
    YOLO_VIDEO_CONFIDENCE_THRESHOLD: float = 0.30
    YOLO_VIDEO_INFERENCE_SIZE: int = 960
    YOLO_OCCUPANCY_CONFIRMATIONS: int = 3
    YOLO_SLOT_OVERLAP_THRESHOLD: float = 0.20
    YOLO_MAX_VIDEO_UPLOAD_MB: int = 1024

    # Payment verification remains responsible for releasing an occupied slot.
    # Keep this false unless the reservation/payment rules are changed later.
    YOLO_ALLOW_AUTOMATIC_VACATE: bool = False

    RESERVATION_TIMEOUT_MINUTES: int = 30

    CORS_ORIGINS: List[str] = ["*"]

    FIREBASE_CREDENTIALS_PATH: str | None = None

    # Razorpay Test/Live credentials.
    # Real values must only be stored in backend/.env.
    RAZORPAY_KEY_ID: str = ""
    RAZORPAY_KEY_SECRET: str = ""
    RAZORPAY_CURRENCY: str = "INR"

    # Razorpay requires the order amount in paise.
    RAZORPAY_MINIMUM_AMOUNT_PAISE: int = 100

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()