"""
API Router pour la gestion des comptes email
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel, EmailStr
from typing import List, Optional
from datetime import datetime

from api.database import get_db
from api.models import EmailAccount, AccountType

router = APIRouter()


class EmailAccountCreate(BaseModel):
    account_type: str
    email_address: EmailStr
    display_name: Optional[str] = None
    credentials: dict  # Format dépend du type de compte


class EmailAccountResponse(BaseModel):
    id: int
    account_type: str
    email_address: str
    display_name: Optional[str]
    is_active: bool
    last_sync: Optional[datetime]
    total_emails_processed: int
    
    class Config:
        from_attributes = True


@router.get("/", response_model=List[EmailAccountResponse])
async def list_accounts(
    db: AsyncSession = Depends(get_db)
):
    """Liste tous les comptes email configurés"""
    query = select(EmailAccount).where(EmailAccount.is_active == True)
    result = await db.execute(query)
    accounts = result.scalars().all()
    
    return accounts


@router.get("/{account_id}", response_model=EmailAccountResponse)
async def get_account(
    account_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Récupérer les détails d'un compte"""
    query = select(EmailAccount).where(EmailAccount.id == account_id)
    result = await db.execute(query)
    account = result.scalar_one_or_none()
    
    if not account:
        raise HTTPException(status_code=404, detail="Account not found")
    
    return account


@router.post("/", response_model=EmailAccountResponse)
async def create_account(
    account: EmailAccountCreate,
    db: AsyncSession = Depends(get_db)
):
    """
    Créer un nouveau compte email avec chiffrement des credentials.

    Format des credentials selon le type:

    - IMAP: {"type": "imap", "imap_server": "...", "imap_port": 993, "username": "...", "password": "...", "use_ssl": true}
    - Gmail OAuth2: {"type": "gmail_oauth2", "token": "...", "refresh_token": "...", "client_id": "...", "client_secret": "..."}
    - Microsoft OAuth2: {"type": "microsoft_oauth2", "token": "...", "refresh_token": "...", "client_id": "...", "client_secret": "...", "tenant_id": "..."}
    """
    from shared.security import encrypt_credentials
    from shared.config import settings

    # Valider le type de compte
    try:
        account_type_enum = AccountType(account.account_type.lower())
    except ValueError:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid account type. Must be one of: {', '.join([t.value for t in AccountType])}"
        )

    # Vérifier que l'email n'existe pas déjà
    existing_query = select(EmailAccount).where(EmailAccount.email_address == account.email_address)
    existing_result = await db.execute(existing_query)
    if existing_result.scalar_one_or_none():
        raise HTTPException(
            status_code=409,
            detail=f"Email account {account.email_address} already exists"
        )

    # Valider les credentials selon le type
    if not account.credentials:
        raise HTTPException(
            status_code=400,
            detail="Credentials are required"
        )

    # Récupérer ou créer l'utilisateur admin (pour simplifier, on utilise toujours l'admin)
    # Dans une vraie app, on utiliserait l'utilisateur authentifié
    from api.models import User
    user_query = select(User).where(User.email == settings.ADMIN_EMAIL)
    user_result = await db.execute(user_query)
    user = user_result.scalar_one_or_none()

    if not user:
        # Créer l'utilisateur admin si nécessaire
        from shared.security import hash_password
        user = User(
            email=settings.ADMIN_EMAIL,
            username="admin",
            hashed_password=hash_password(settings.ADMIN_PASSWORD),
            full_name="Administrator",
            is_admin=True,
            is_active=True
        )
        db.add(user)
        await db.flush()

    # Chiffrer les credentials
    try:
        encrypted_creds = encrypt_credentials(account.credentials)
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to encrypt credentials: {str(e)}"
        )

    # Créer le compte email
    new_account = EmailAccount(
        user_id=user.id,
        account_type=account_type_enum,
        email_address=account.email_address,
        display_name=account.display_name or account.email_address,
        encrypted_credentials=encrypted_creds,
        is_active=True,
        sync_enabled=True
    )

    db.add(new_account)
    await db.commit()
    await db.refresh(new_account)

    return new_account


@router.delete("/{account_id}")
async def delete_account(
    account_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Supprimer un compte email"""
    query = select(EmailAccount).where(EmailAccount.id == account_id)
    result = await db.execute(query)
    account = result.scalar_one_or_none()
    
    if not account:
        raise HTTPException(status_code=404, detail="Account not found")
    
    account.is_active = False
    await db.commit()
    
    return {"message": "Account deactivated successfully"}
