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
    # Les credentials seront gérés séparément selon le type


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
    """Créer un nouveau compte email - TODO: implémenter la configuration complète"""
    # TODO: Implémenter la création complète avec chiffrement des credentials
    
    raise HTTPException(
        status_code=501,
        detail="Account creation not yet implemented. Use the setup wizard."
    )


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
