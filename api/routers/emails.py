"""
API Router pour la consultation des emails
"""
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

from api.database import get_db
from api.models import Email, EmailCategory, ProcessingStatus

router = APIRouter()


class EmailResponse(BaseModel):
    id: int
    message_id: str
    subject: str
    sender: str
    date_received: datetime
    category: str
    classification_confidence: Optional[int]
    has_attachments: bool
    status: str
    body_preview: Optional[str]
    
    class Config:
        from_attributes = True


class EmailListResponse(BaseModel):
    total: int
    emails: List[EmailResponse]
    page: int
    page_size: int


@router.get("/", response_model=EmailListResponse)
async def list_emails(
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=100),
    category: Optional[str] = None,
    status: Optional[str] = None,
    account_id: Optional[int] = None,
    db: AsyncSession = Depends(get_db)
):
    """Liste les emails avec pagination et filtres"""
    
    # Construire la requête de base
    query = select(Email)
    
    # Appliquer les filtres
    if category:
        try:
            cat = EmailCategory(category)
            query = query.where(Email.category == cat)
        except ValueError:
            pass
    
    if status:
        try:
            stat = ProcessingStatus(status)
            query = query.where(Email.status == stat)
        except ValueError:
            pass
    
    if account_id:
        query = query.where(Email.account_id == account_id)
    
    # Ordre chronologique inverse
    query = query.order_by(desc(Email.date_received))
    
    # Compter le total
    from sqlalchemy import func
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar()
    
    # Pagination
    offset = (page - 1) * page_size
    query = query.offset(offset).limit(page_size)
    
    # Exécuter
    result = await db.execute(query)
    emails = result.scalars().all()
    
    return EmailListResponse(
        total=total,
        emails=emails,
        page=page,
        page_size=page_size
    )


@router.get("/{email_id}", response_model=EmailResponse)
async def get_email(
    email_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Récupérer les détails d'un email"""
    query = select(Email).where(Email.id == email_id)
    result = await db.execute(query)
    email = result.scalar_one_or_none()
    
    if not email:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Email not found")
    
    return email
