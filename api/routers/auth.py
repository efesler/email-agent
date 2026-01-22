"""
API Router pour l'authentification
"""
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from pydantic import BaseModel
from typing import Optional
from datetime import datetime, timedelta
from jose import JWTError, jwt
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from api.database import get_db
from api.models import User
from shared.security import verify_password
from shared.config import settings

router = APIRouter()

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """
    Créer un JWT access token.

    Args:
        data: Données à encoder dans le token (user_id, username, etc.)
        expires_delta: Durée de validité du token

    Returns:
        JWT token encodé
    """
    to_encode = data.copy()

    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)

    to_encode.update({"exp": expire})

    encoded_jwt = jwt.encode(
        to_encode,
        settings.SECRET_KEY,
        algorithm=settings.JWT_ALGORITHM
    )

    return encoded_jwt


async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db)
) -> User:
    """
    Récupérer l'utilisateur courant depuis le JWT token.

    Args:
        token: JWT token depuis l'header Authorization
        db: Session de base de données

    Returns:
        User object

    Raises:
        HTTPException: Si le token est invalide ou l'utilisateur n'existe pas
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

    try:
        # Décoder le JWT token
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM]
        )

        user_id: int = payload.get("sub")
        if user_id is None:
            raise credentials_exception

    except JWTError:
        raise credentials_exception

    # Récupérer l'utilisateur depuis la DB
    user = await db.get(User, user_id)

    if user is None:
        raise credentials_exception

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is inactive"
        )

    return user


class Token(BaseModel):
    access_token: str
    token_type: str


class UserResponse(BaseModel):
    """Response model pour les informations utilisateur"""
    id: int
    email: str
    username: str
    full_name: Optional[str]
    is_active: bool
    is_admin: bool

    class Config:
        from_attributes = True


@router.post("/login", response_model=Token)
async def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: AsyncSession = Depends(get_db)
):
    """
    Authentifier un utilisateur et générer un JWT token.

    Args:
        form_data: Formulaire OAuth2 avec username et password
        db: Session de base de données

    Returns:
        Token: JWT access token

    Raises:
        HTTPException: Si les credentials sont incorrects
    """
    # Chercher l'utilisateur par username ou email
    query = select(User).where(
        (User.username == form_data.username) | (User.email == form_data.username)
    )
    result = await db.execute(query)
    user = result.scalar_one_or_none()

    # Vérifier que l'utilisateur existe et le password est correct
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Vérifier que le compte est actif
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is inactive"
        )

    # Mettre à jour last_login
    user.last_login = datetime.utcnow()
    await db.commit()

    # Créer le JWT token
    access_token = create_access_token(
        data={"sub": user.id, "username": user.username}
    )

    return {
        "access_token": access_token,
        "token_type": "bearer"
    }


@router.get("/me", response_model=UserResponse)
async def read_current_user(current_user: User = Depends(get_current_user)):
    """
    Récupérer les informations de l'utilisateur courant.

    Args:
        current_user: Utilisateur authentifié (injecté par dependency)

    Returns:
        UserResponse: Informations de l'utilisateur
    """
    return current_user
