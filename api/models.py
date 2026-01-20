"""
Database models pour Email Agent AI
"""
from sqlalchemy import Column, Integer, String, Boolean, DateTime, Text, ForeignKey, Enum, JSON
from sqlalchemy.orm import relationship
from sqlalchemy.ext.declarative import declarative_base
from datetime import datetime
import enum

Base = declarative_base()


class AccountType(str, enum.Enum):
    """Types de comptes email supportés"""
    GMAIL = "gmail"
    OUTLOOK = "outlook"
    IMAP = "imap"


class ProcessingStatus(str, enum.Enum):
    """Statuts de traitement des emails"""
    PENDING = "pending"
    PROCESSING = "processing"
    CLASSIFIED = "classified"
    ARCHIVED = "archived"
    DELETED = "deleted"
    ERROR = "error"


class EmailCategory(str, enum.Enum):
    """Catégories de classification"""
    INVOICE = "invoice"          # Factures
    RECEIPT = "receipt"          # Reçus
    DOCUMENT = "document"        # Documents partagés
    PROFESSIONAL = "professional" # Email pro intéressant
    NEWSLETTER = "newsletter"    # Newsletters
    PROMOTION = "promotion"      # Promotions
    SOCIAL = "social"           # Réseaux sociaux
    NOTIFICATION = "notification" # Notifications
    PERSONAL = "personal"        # Personnel
    SPAM = "spam"               # Spam
    UNKNOWN = "unknown"         # Non classifié


class EmailAccount(Base):
    """Compte email configuré"""
    __tablename__ = "email_accounts"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    # Configuration
    account_type = Column(Enum(AccountType), nullable=False)
    email_address = Column(String(255), nullable=False, unique=True)
    display_name = Column(String(255))
    
    # Credentials (chiffrés)
    encrypted_credentials = Column(Text, nullable=False)
    
    # Status
    is_active = Column(Boolean, default=True)
    last_sync = Column(DateTime, nullable=True)
    sync_enabled = Column(Boolean, default=True)
    
    # Statistiques
    total_emails_processed = Column(Integer, default=0)
    last_error = Column(Text, nullable=True)
    
    # Métadonnées
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relations
    user = relationship("User", back_populates="email_accounts")
    emails = relationship("Email", back_populates="account", cascade="all, delete-orphan")


class Email(Base):
    """Email traité"""
    __tablename__ = "emails"
    
    id = Column(Integer, primary_key=True, index=True)
    account_id = Column(Integer, ForeignKey("email_accounts.id"), nullable=False)
    
    # Identifiants email
    message_id = Column(String(500), unique=True, index=True)
    thread_id = Column(String(255), nullable=True)
    
    # Contenu
    subject = Column(String(500))
    sender = Column(String(255), index=True)
    recipients = Column(JSON)  # Liste des destinataires
    date_received = Column(DateTime, index=True)
    
    # Classification
    category = Column(Enum(EmailCategory), default=EmailCategory.UNKNOWN, index=True)
    classification_confidence = Column(Integer)  # 0-100
    classification_reason = Column(Text)
    
    # Métadonnées
    has_attachments = Column(Boolean, default=False)
    attachment_count = Column(Integer, default=0)
    attachment_types = Column(JSON)  # Types de pièces jointes
    body_preview = Column(Text)  # Premiers 500 caractères
    
    # Status et actions
    status = Column(Enum(ProcessingStatus), default=ProcessingStatus.PENDING, index=True)
    archived_folder = Column(String(255), nullable=True)
    is_deleted = Column(Boolean, default=False)
    deleted_at = Column(DateTime, nullable=True)
    
    # Métadonnées de traitement
    processed_at = Column(DateTime, nullable=True)
    processing_time_ms = Column(Integer)  # Temps de traitement en ms
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, index=True)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relations
    account = relationship("EmailAccount", back_populates="emails")
    attachments = relationship("EmailAttachment", back_populates="email", cascade="all, delete-orphan")


class EmailAttachment(Base):
    """Pièce jointe d'email"""
    __tablename__ = "email_attachments"
    
    id = Column(Integer, primary_key=True, index=True)
    email_id = Column(Integer, ForeignKey("emails.id"), nullable=False)
    
    # Métadonnées
    filename = Column(String(255))
    content_type = Column(String(100))
    size_bytes = Column(Integer)
    
    # Analyse
    is_invoice = Column(Boolean, default=False)
    is_receipt = Column(Boolean, default=False)
    extracted_text = Column(Text, nullable=True)  # Texte extrait (OCR/PDF)
    
    # Stockage (optionnel - chemin vers fichier sauvegardé)
    storage_path = Column(String(500), nullable=True)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relations
    email = relationship("Email", back_populates="attachments")


class User(Base):
    """Utilisateur de l'application"""
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    username = Column(String(100), unique=True, index=True)
    hashed_password = Column(String(255), nullable=False)
    
    # Profil
    full_name = Column(String(255))
    is_active = Column(Boolean, default=True)
    is_admin = Column(Boolean, default=False)
    
    # Préférences
    preferences = Column(JSON, default=dict)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    last_login = Column(DateTime, nullable=True)
    
    # Relations
    email_accounts = relationship("EmailAccount", back_populates="user", cascade="all, delete-orphan")


class ClassificationRule(Base):
    """Règles de classification personnalisées"""
    __tablename__ = "classification_rules"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    # Règle
    name = Column(String(255), nullable=False)
    description = Column(Text)
    priority = Column(Integer, default=0)  # Plus haut = plus prioritaire
    is_active = Column(Boolean, default=True)
    
    # Conditions (JSON)
    conditions = Column(JSON, nullable=False)
    # Exemple: {"sender_contains": "@company.com", "subject_contains": "invoice"}
    
    # Action
    target_category = Column(Enum(EmailCategory), nullable=False)
    target_folder = Column(String(255), nullable=True)
    auto_delete = Column(Boolean, default=False)
    
    # Statistiques
    match_count = Column(Integer, default=0)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class ProcessingLog(Base):
    """Logs de traitement pour analyse et débogage"""
    __tablename__ = "processing_logs"
    
    id = Column(Integer, primary_key=True, index=True)
    email_id = Column(Integer, ForeignKey("emails.id"), nullable=True)
    
    # Log
    level = Column(String(20))  # INFO, WARNING, ERROR
    message = Column(Text)
    details = Column(JSON)
    
    # Context
    component = Column(String(100))  # classifier, imap_sync, etc.
    processing_time_ms = Column(Integer, nullable=True)
    
    created_at = Column(DateTime, default=datetime.utcnow, index=True)
