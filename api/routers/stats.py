"""
API Router pour les statistiques
"""
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from datetime import datetime, timedelta
from typing import Dict

from api.database import get_db
from api.models import Email, EmailCategory, ProcessingStatus, EmailAccount

router = APIRouter()


@router.get("/dashboard")
async def get_dashboard_stats(
    db: AsyncSession = Depends(get_db)
) -> Dict:
    """Statistiques du dashboard"""
    
    # Total d'emails traités
    total_query = select(func.count(Email.id))
    total_result = await db.execute(total_query)
    total_emails = total_result.scalar()
    
    # Emails traités aujourd'hui
    today = datetime.utcnow().date()
    today_query = select(func.count(Email.id)).where(
        func.date(Email.created_at) == today
    )
    today_result = await db.execute(today_query)
    today_emails = today_result.scalar()
    
    # Répartition par catégorie
    category_query = select(
        Email.category,
        func.count(Email.id).label('count')
    ).group_by(Email.category)
    category_result = await db.execute(category_query)
    categories = {
        row.category.value: row.count 
        for row in category_result
    }
    
    # Comptes actifs
    accounts_query = select(func.count(EmailAccount.id)).where(
        EmailAccount.is_active == True
    )
    accounts_result = await db.execute(accounts_query)
    active_accounts = accounts_result.scalar()
    
    # Dernière synchronisation
    last_sync_query = select(func.max(EmailAccount.last_sync))
    last_sync_result = await db.execute(last_sync_query)
    last_sync = last_sync_result.scalar()
    
    return {
        "total_emails": total_emails,
        "today_emails": today_emails,
        "categories": categories,
        "active_accounts": active_accounts,
        "last_sync": last_sync.isoformat() if last_sync else None,
        "timestamp": datetime.utcnow().isoformat()
    }


@router.get("/timeline")
async def get_timeline_stats(
    days: int = 7,
    db: AsyncSession = Depends(get_db)
) -> Dict:
    """Statistiques sur les derniers jours"""
    
    # Emails par jour sur les X derniers jours
    start_date = datetime.utcnow() - timedelta(days=days)
    
    query = select(
        func.date(Email.created_at).label('date'),
        func.count(Email.id).label('count')
    ).where(
        Email.created_at >= start_date
    ).group_by(
        func.date(Email.created_at)
    ).order_by(
        func.date(Email.created_at)
    )
    
    result = await db.execute(query)
    timeline = [
        {
            'date': row.date.isoformat(),
            'count': row.count
        }
        for row in result
    ]
    
    return {
        "days": days,
        "timeline": timeline
    }


@router.get("/performance")
async def get_performance_stats(
    db: AsyncSession = Depends(get_db)
) -> Dict:
    """Statistiques de performance"""
    
    # Temps moyen de traitement
    avg_time_query = select(
        func.avg(Email.processing_time_ms).label('avg_ms')
    ).where(
        Email.processing_time_ms.isnot(None)
    )
    avg_result = await db.execute(avg_time_query)
    avg_time = avg_result.scalar() or 0
    
    # Emails en erreur
    error_query = select(func.count(Email.id)).where(
        Email.status == ProcessingStatus.ERROR
    )
    error_result = await db.execute(error_query)
    error_count = error_result.scalar()
    
    # Confiance moyenne de classification
    confidence_query = select(
        func.avg(Email.classification_confidence).label('avg_confidence')
    ).where(
        Email.classification_confidence.isnot(None)
    )
    confidence_result = await db.execute(confidence_query)
    avg_confidence = confidence_result.scalar() or 0
    
    return {
        "avg_processing_time_ms": round(avg_time, 2),
        "avg_processing_time_seconds": round(avg_time / 1000, 2),
        "error_count": error_count,
        "avg_classification_confidence": round(avg_confidence, 2)
    }
