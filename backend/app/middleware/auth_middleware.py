from fastapi.security import OAuth2PasswordBearer
from fastapi import Depends
from app.services.auth_service import get_current_user

# Just re-exporting the dependencies from auth_service
__all__ = ["OAuth2PasswordBearer", "get_current_user"]
