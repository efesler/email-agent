"""
Tâches Celery pour la classification des emails
"""
from celery import shared_task
import logging
from datetime import datetime

logger = logging.getLogger(__name__)


@shared_task(name='worker.tasks.classification.classify_email')
def classify_email(email_id: int):
    """
    Classifier un email avec Ollama
    
    Args:
        email_id: ID de l'email à classifier
    """
    logger.info(f"Classifying email {email_id}")
    
    # TODO: Implémenter la classification
    # 1. Récupérer l'email depuis la DB
    # 2. Appeler le classificateur Ollama
    # 3. Mettre à jour l'email avec la catégorie
    # 4. Logger le temps de traitement
    # 5. Exécuter l'action (archivage, suppression, etc.)
    
    logger.info(f"Email {email_id} classified (stub)")
    return {
        'email_id': email_id,
        'category': 'unknown',
        'confidence': 0,
        'status': 'completed'
    }


@shared_task(name='worker.tasks.classification.reclassify_emails')
def reclassify_emails(category: str = None):
    """
    Re-classifier des emails (utile après ajout de règles)
    
    Args:
        category: Si spécifié, ne reclassifier que cette catégorie
    """
    logger.info(f"Reclassifying emails (category: {category})")
    
    # TODO: Implémenter la reclassification
    # 1. Récupérer les emails à reclassifier
    # 2. Pour chaque email, lancer classify_email
    # 3. Logger les résultats
    
    logger.info("Reclassification completed (stub)")
    return {
        'emails_reclassified': 0,
        'status': 'completed'
    }
