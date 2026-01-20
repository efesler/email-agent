"""
API Router pour la classification et les règles
"""
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel
from typing import List, Optional

from api.database import get_db
from api.models import ClassificationRule, EmailCategory

router = APIRouter()


class ClassificationRuleResponse(BaseModel):
    id: int
    name: str
    description: Optional[str]
    priority: int
    is_active: bool
    target_category: str
    target_folder: Optional[str]
    match_count: int
    
    class Config:
        from_attributes = True


class TestClassificationRequest(BaseModel):
    subject: str
    sender: str
    body_preview: str
    has_attachments: bool = False
    attachment_names: Optional[List[str]] = None


class TestClassificationResponse(BaseModel):
    category: str
    confidence: int
    reason: str
    processing_time_ms: int


@router.get("/rules", response_model=List[ClassificationRuleResponse])
async def list_rules(
    db: AsyncSession = Depends(get_db)
):
    """Liste toutes les règles de classification"""
    query = select(ClassificationRule).order_by(ClassificationRule.priority.desc())
    result = await db.execute(query)
    rules = result.scalars().all()
    
    return rules


@router.post("/test", response_model=TestClassificationResponse)
async def test_classification(
    request: TestClassificationRequest
):
    """Tester la classification d'un email sans le sauvegarder"""
    from worker.classifiers.ollama_classifier import classifier
    import time
    
    start = time.time()
    
    result = await classifier.classify_email(
        subject=request.subject,
        sender=request.sender,
        body_preview=request.body_preview,
        has_attachments=request.has_attachments,
        attachment_names=request.attachment_names
    )
    
    processing_time = int((time.time() - start) * 1000)
    
    return TestClassificationResponse(
        category=result['category'].value,
        confidence=result['confidence'],
        reason=result['reason'],
        processing_time_ms=processing_time
    )


@router.get("/categories")
async def list_categories():
    """Liste toutes les catégories disponibles"""
    return {
        "categories": [
            {
                "value": cat.value,
                "name": cat.name,
                "description": _get_category_description(cat)
            }
            for cat in EmailCategory
        ]
    }


def _get_category_description(category: EmailCategory) -> str:
    """Descriptions des catégories"""
    descriptions = {
        EmailCategory.INVOICE: "Factures et documents de facturation",
        EmailCategory.RECEIPT: "Reçus de paiement et confirmations",
        EmailCategory.DOCUMENT: "Documents partagés (Drive, Dropbox, etc.)",
        EmailCategory.PROFESSIONAL: "Emails professionnels importants",
        EmailCategory.NEWSLETTER: "Newsletters et bulletins d'information",
        EmailCategory.PROMOTION: "Promotions et publicités",
        EmailCategory.SOCIAL: "Notifications de réseaux sociaux",
        EmailCategory.NOTIFICATION: "Notifications automatiques",
        EmailCategory.PERSONAL: "Emails personnels",
        EmailCategory.SPAM: "Spam et courrier indésirable",
        EmailCategory.UNKNOWN: "Non classifié"
    }
    return descriptions.get(category, "")
