"""
API Router pour l'authentification
"""
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from pydantic import BaseModel
from typing import Optional

router = APIRouter()

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")


class Token(BaseModel):
    access_token: str
    token_type: str


class User(BaseModel):
    email: str
    username: str
    is_active: bool = True


@router.post("/login", response_model=Token)
async def login(form_data: OAuth2PasswordRequestForm = Depends()):
    """Login endpoint - TODO: implémenter la vérification réelle"""
    # TODO: Vérifier les credentials dans la base de données
    # TODO: Générer un vrai JWT token
    
    # Pour l'instant, accepter admin/changeme
    if form_data.username != "admin" or form_data.password != "changeme":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Token factice pour le développement
    return {
        "access_token": "fake-jwt-token-for-development",
        "token_type": "bearer"
    }


@router.get("/me", response_model=User)
async def get_current_user(token: str = Depends(oauth2_scheme)):
    """Récupérer l'utilisateur courant - TODO: implémenter"""
    # TODO: Décoder et vérifier le JWT
    # TODO: Récupérer l'utilisateur depuis la base
    
    return User(
        email="admin@example.com",
        username="admin",
        is_active=True
    )
