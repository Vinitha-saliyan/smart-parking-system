from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.models.user import User
from app.schemas.user_schema import (
    UserCreate,
    UserLogin,
    UserResponse,
    TokenResponse,
    UserUpdate,
    PasswordResetRequest,
)
from app.services.auth_service import (
    register_user,
    authenticate_user,
    create_access_token,
    create_refresh_token,
    get_current_user,
)
from fastapi.security import OAuth2PasswordRequestForm
import logging

router = APIRouter(prefix="/api/v1/auth", tags=["Authentication"])
logger = logging.getLogger(__name__)


@router.post("/register", response_model=TokenResponse)
async def register(
    user_data: UserCreate,
    db: AsyncSession = Depends(get_db),
):
    user = await register_user(db, user_data)

    access_token = create_access_token(
        data={"sub": str(user.id), "role": user.role}
    )

    refresh_token = create_refresh_token(
        data={"sub": str(user.id)}
    )

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
    }


@router.post("/login", response_model=TokenResponse)
async def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: AsyncSession = Depends(get_db),
):
    user = await authenticate_user(
        db,
        form_data.username,
        form_data.password,
    )

    access_token = create_access_token(
        data={"sub": str(user.id), "role": user.role}
    )

    refresh_token = create_refresh_token(
        data={"sub": str(user.id)}
    )

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
    }


@router.post("/refresh", response_model=TokenResponse)
async def refresh(refresh_token: str):
    pass


@router.get("/me", response_model=UserResponse)
async def read_users_me(
    current_user: User = Depends(get_current_user),
):
    return current_user


@router.put("/me", response_model=UserResponse)
async def update_users_me(
    update_data: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if update_data.full_name is not None:
        current_user.full_name = update_data.full_name

    if update_data.phone is not None:
        current_user.phone = update_data.phone

    if update_data.avatar_url is not None:
        current_user.avatar_url = update_data.avatar_url

    await db.commit()
    await db.refresh(current_user)

    return current_user


@router.post("/forgot-password")
async def forgot_password(req: PasswordResetRequest):
    logger.info(f"Password reset requested for {req.email}")

    return {
        "message": "If the email is registered, a reset link has been sent."
    }
