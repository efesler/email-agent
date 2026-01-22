# 🤖 AGENT.md - Guide pour AI Coding Agents

> **Audience** : GitHub Copilot, Cursor, Cody, Tabnine, et tous AI coding assistants  
> **Objectif** : Contexte pour contribuer efficacement à Email Agent AI

---

## 📋 Projet: Email Agent AI

**Gestionnaire d'emails intelligent et self-hosted**

- 🤖 **Classification IA** via Ollama LLM (local, pas de cloud)
- 📧 **Multi-comptes** : Gmail, Outlook, IMAP
- 🔒 **Privacy-first** : Toutes données locales
- 💰 **Gratuit** : Oracle Cloud Free Tier (0€/mois)
- 🐳 **Containerisé** : Docker + Docker Compose
- 🚀 **Production-ready** : Code professionnel, pas POC

---

## 🏗️ Architecture rapide

```
┌─────────┐
│  Nginx  │ :80/443
└────┬────┘
     │
┌────▼─────┐      ┌──────────┐      ┌────────┐
│ FastAPI  │─────►│PostgreSQL│      │ Ollama │
│   API    │      └──────────┘      │  LLM   │
└────┬─────┘                         └────────┘
     │              ┌─────────┐           ▲
     └─────────────►│  Redis  │           │
                    └────┬────┘           │
                         │                │
                    ┌────▼────┐           │
                    │ Celery  │───────────┘
                    │ Workers │
                    └─────────┘
```

**Services**:
- `api`: FastAPI REST backend (Python 3.11+)
- `worker`: Celery async tasks
- `db`: PostgreSQL 15
- `redis`: Queue + Cache
- `ollama`: LLM local (Mistral 7B)
- `nginx`: Reverse proxy

---

## 📚 Stack

```yaml
Language: Python 3.11+
Framework: FastAPI 0.109+
ORM: SQLAlchemy 2.0+ (async)
Queue: Celery 5.3+ + Redis
Database: PostgreSQL 15
LLM: Ollama + Mistral 7B
Container: Docker + Docker Compose
```

**Key Libraries**:
```python
fastapi         # Web framework
sqlalchemy      # ORM async
celery          # Task queue
redis           # Cache/broker
pydantic        # Validation
httpx           # HTTP client (Ollama)
cryptography    # Encryption
python-jose     # JWT
imapclient      # Email IMAP
```

---

## 📁 Structure projet

```
email-agent/
├── api/                    # FastAPI backend
│   ├── main.py            # Entry point
│   ├── models.py          # SQLAlchemy models
│   ├── database.py        # DB connection
│   └── routers/           # API endpoints
│       ├── auth.py
│       ├── accounts.py
│       ├── emails.py
│       ├── classification.py
│       └── stats.py
│
├── worker/                # Celery workers
│   ├── celery_app.py     # Config + scheduler
│   ├── classifiers/
│   │   └── ollama_classifier.py
│   └── tasks/
│       ├── email_sync.py
│       ├── classification.py
│       └── maintenance.py
│
├── shared/               # Code partagé
│   └── config.py        # Settings (Pydantic)
│
├── tests/               # Tests pytest
├── scripts/             # Scripts deploy/backup
├── config/              # Nginx, rules YAML
└── docker/              # Dockerfiles
```

---

## 🎨 Conventions de code

### Python

```python
# 1. Type hints OBLIGATOIRES
async def get_email(email_id: int) -> Email | None:
    pass

# 2. Docstrings (Google style)
def classify_email(email: Email) -> dict[str, Any]:
    """
    Classify email using Ollama.
    
    Args:
        email: Email object to classify
        
    Returns:
        Dict with category, confidence, reason
    """
    pass

# 3. Async/await pour IO
async def fetch_emails(account_id: int):
    # Toujours async pour DB, HTTP, files
    pass

# 4. Naming
class EmailAccount:      # PascalCase
def sync_account():      # snake_case
MAX_RETRIES = 3          # UPPER_CASE

# 5. Imports ordering
# Standard lib
import os
from datetime import datetime

# Third-party
from fastapi import APIRouter
from sqlalchemy import select

# Local
from api.models import Email

# 6. Logging
import logging
logger = logging.getLogger(__name__)

logger.info("Operation started")
logger.error("Error", exc_info=True)  # Toujours exc_info pour errors
```

### Fichiers

```python
# Template nouveau fichier
"""
Module description.

This module handles X functionality.
"""
import logging

logger = logging.getLogger(__name__)

# Your code

if __name__ == "__main__":
    # Example usage
    pass
```

---

## 🔑 Patterns clés

### 1. FastAPI Endpoint

```python
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from api.database import get_db

router = APIRouter()

@router.get("/emails/{email_id}")
async def get_email(
    email_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Get email by ID."""
    result = await db.execute(
        select(Email).where(Email.id == email_id)
    )
    email = result.scalar_one_or_none()
    
    if not email:
        raise HTTPException(status_code=404, detail="Email not found")
    
    return email
```

### 2. Celery Task

```python
from celery import shared_task

@shared_task(name='worker.tasks.sync_account', bind=True, max_retries=3)
def sync_account(self, account_id: int):
    """Sync emails from account."""
    try:
        # Import inside to avoid circular imports
        from api.database import get_db_context
        
        async with get_db_context() as db:
            # Your logic
            pass
        
        return {'status': 'success'}
    except Exception as exc:
        raise self.retry(exc=exc)
```

### 3. Pydantic Model

```python
from pydantic import BaseModel, EmailStr

class EmailAccountCreate(BaseModel):
    """Request model."""
    email_address: EmailStr
    account_type: str  # gmail|outlook|imap
    
class EmailAccountResponse(BaseModel):
    """Response model."""
    id: int
    email_address: str
    is_active: bool
    
    class Config:
        from_attributes = True  # For SQLAlchemy
```

### 4. SQLAlchemy Model

```python
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from sqlalchemy.orm import relationship

class Email(Base):
    __tablename__ = "emails"
    
    id = Column(Integer, primary_key=True)
    account_id = Column(Integer, ForeignKey("email_accounts.id"))
    subject = Column(String(500))
    sender = Column(String(255), index=True)
    date_received = Column(DateTime, index=True)
    category = Column(Enum(EmailCategory), index=True)
    
    account = relationship("EmailAccount", back_populates="emails")
```

---

## 🗄️ Base de données

### Modèles principaux

```python
User
  ├── id, email, hashed_password
  └── email_accounts (1:N)

EmailAccount
  ├── id, user_id, email_address
  ├── account_type (gmail|outlook|imap)
  ├── encrypted_credentials
  └── emails (1:N)

Email
  ├── id, account_id, message_id
  ├── subject, sender, date_received
  ├── category, confidence
  └── attachments (1:N)
```

### Enum types

```python
class EmailCategory(str, enum.Enum):
    INVOICE = "invoice"
    RECEIPT = "receipt"
    DOCUMENT = "document"
    PROFESSIONAL = "professional"
    NEWSLETTER = "newsletter"
    PROMOTION = "promotion"
    SOCIAL = "social"
    NOTIFICATION = "notification"
    PERSONAL = "personal"
    SPAM = "spam"
    UNKNOWN = "unknown"
```

---

## 🔒 Sécurité

### 1. Credentials

```python
from cryptography.fernet import Fernet
import json

# Encrypt
cipher = Fernet(settings.ENCRYPTION_KEY.encode())
encrypted = cipher.encrypt(json.dumps(creds).encode())

# Decrypt
decrypted = cipher.decrypt(encrypted)
creds = json.loads(decrypted.decode())
```

### 2. JWT

```python
from jose import jwt
from datetime import timedelta

token = jwt.encode(
    {"sub": user_id, "exp": datetime.utcnow() + timedelta(hours=24)},
    settings.SECRET_KEY,
    algorithm="HS256"
)
```

### 3. Jamais en clair

❌ **Ne JAMAIS faire** :
```python
# BAD
account.password = "mypassword"  # Jamais en clair
settings.API_KEY = "key123"       # Jamais hardcodé
```

✅ **Toujours faire** :
```python
# GOOD
account.encrypted_credentials = encrypt(creds)
api_key = os.getenv("API_KEY")  # Depuis .env
```

---

## 🧪 Tests

### Exemple test

```python
import pytest
from httpx import AsyncClient

@pytest.mark.asyncio
async def test_classify_email(client: AsyncClient):
    """Test email classification."""
    response = await client.post("/api/classification/test", json={
        "subject": "Invoice January",
        "sender": "billing@company.com",
        "body_preview": "Amount: 1250€"
    })
    
    assert response.status_code == 200
    data = response.json()
    assert data["category"] == "invoice"
    assert data["confidence"] >= 80
```

### Lancer tests

```bash
# Tous les tests
pytest

# Avec coverage
pytest --cov=api --cov=worker

# Tests spécifiques
pytest tests/test_api/test_classification.py
```

---

## 🗺️ TODOs & Roadmap

### Phase 1: Email Connectors (PRIORITÉ)

```python
# shared/integrations/imap_connector.py
class IMAPConnector:
    """
    TODO:
    - Connect with SSL
    - Authenticate
    - Fetch emails since last sync
    - Parse MIME messages
    - Handle attachments
    - Move to folders
    """

# shared/integrations/gmail_connector.py  
class GmailConnector:
    """
    TODO:
    - OAuth2 flow
    - Token refresh
    - Gmail API calls
    """
```

### Phase 2: Actions

```python
# worker/actions/email_actions.py

async def archive_email(email: Email, folder: str):
    """TODO: Move email to folder."""
    
async def delete_email(email: Email):
    """TODO: Delete email."""
```

### Phase 3: Advanced

- OCR pour extraction données factures
- Fine-tuning modèle Ollama
- Interface web (React)
- Application mobile

---

## 📋 Checklist développement

Avant de committer du code :

- [ ] Type hints partout
- [ ] Docstrings pour fonctions publiques
- [ ] Logging approprié
- [ ] Error handling robuste
- [ ] Async/await pour IO
- [ ] Tests ajoutés/mis à jour
- [ ] Pas de secrets en dur
- [ ] Code formaté (black)
- [ ] Imports triés

---

## 🚀 Workflow

### Dev local

```bash
# 1. Démarrer services
docker-compose -f docker-compose.dev.yml up

# 2. Accéder
# API: http://localhost:8000
# DB: localhost:5432 (adminer sur :8080)
# Redis: localhost:6379

# 3. Tests
pytest

# 4. Logs
docker-compose logs -f api worker
```

### Nouvelle feature

```bash
# 1. Branche
git checkout -b feature/nom

# 2. Coder + tester

# 3. Commit
git commit -m "feat: Description"

# 4. Push + PR
git push origin feature/nom
```

### Migration DB

```bash
# Modifier api/models.py
# Puis:
alembic revision --autogenerate -m "Description"
alembic upgrade head
```

---

## 💡 Ressources

### Documentation principale
- **README.md** : Vue d'ensemble complète
- **QUICKSTART.md** : Déploiement Oracle Cloud
- **CLAUDE.md** : Guide détaillé (si disponible)

### Code clés
- **api/main.py** : Entry point API
- **api/models.py** : Schéma DB
- **worker/celery_app.py** : Config Celery
- **worker/classifiers/ollama_classifier.py** : Classification IA
- **shared/config.py** : Configuration

### Commandes utiles

```bash
# Makefile disponible
make help       # Liste commandes
make up         # Démarrer
make logs       # Voir logs
make test       # Tests
make backup     # Backup DB

# Docker
docker-compose ps              # Status
docker-compose logs -f api     # Logs API
docker-compose exec api bash   # Shell
```

---

## ⚠️ Pièges à éviter

### 1. Circular imports
```python
# ❌ BAD: Import au top-level dans tasks
from api.models import Email  # Circular!

# ✅ GOOD: Import inside function
def my_task():
    from api.models import Email  # OK
```

### 2. Blocking calls
```python
# ❌ BAD: Sync dans async context
def sync_function():
    time.sleep(10)  # Bloque event loop!

# ✅ GOOD: Async
async def async_function():
    await asyncio.sleep(10)  # Non-bloquant
```

### 3. DB sessions
```python
# ❌ BAD: Session globale
session = AsyncSessionLocal()  # Ne pas faire

# ✅ GOOD: Dependency injection
async def endpoint(db: AsyncSession = Depends(get_db)):
    pass
```

---

## 🎯 Rappels finaux

### Principes
- **Clarté > Cleverness** : Simple et lisible
- **Safety > Speed** : Sécurité d'abord
- **Test > Hope** : Tester, pas espérer

### Style
- Python PEP 8
- Async/await partout
- Type hints obligatoires
- Docstrings pour public APIs
- Logging pour debug

### Qualité
- pytest pour tests
- black pour formatting
- mypy pour type checking
- flake8 pour linting

---

## 📞 Besoin d'aide ?

1. Lire **README.md** et **CLAUDE.md**
2. Chercher dans **issues** GitHub
3. Consulter code existant similaire
4. Créer issue avec tag `question`

---

**Happy coding! Ce projet valorise la qualité et la clarté du code.** 🚀

**Version**: 1.0.0 | **Date**: 2025-01-20
