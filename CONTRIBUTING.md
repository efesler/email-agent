# Guide de Contribution

Merci de votre intérêt pour contribuer à Email Agent AI ! 🎉

## Comment contribuer

### 1. Fork et Clone

```bash
# Fork le repo sur GitHub, puis :
git clone https://github.com/VOTRE-USERNAME/email-agent.git
cd email-agent
```

### 2. Créer une branche

```bash
git checkout -b feature/ma-nouvelle-fonctionnalite
# ou
git checkout -b fix/correction-bug
```

### 3. Développement local

```bash
# Copier la config
cp .env.example .env

# Démarrer en mode dev
docker-compose -f docker-compose.yml up -d

# Installer les dépendances de dev
pip install -r requirements-dev.txt
```

### 4. Faire vos modifications

- Suivre les conventions de code Python (PEP 8)
- Ajouter des tests si applicable
- Documenter votre code
- Mettre à jour le README si nécessaire

### 5. Tests

```bash
# Lancer les tests
make test

# Avec coverage
make test-cov

# Linter
make lint
```

### 6. Commit et Push

```bash
git add .
git commit -m "feat: description de la fonctionnalité"
git push origin feature/ma-nouvelle-fonctionnalite
```

Convention de commit :
- `feat:` nouvelle fonctionnalité
- `fix:` correction de bug
- `docs:` documentation
- `style:` formatage
- `refactor:` refactoring
- `test:` ajout de tests
- `chore:` tâches de maintenance

### 7. Pull Request

Ouvrez une Pull Request sur GitHub avec :
- Description claire des changements
- Références aux issues si applicable
- Screenshots si changements visuels

## Structure du projet

```
email-agent/
├── api/              # FastAPI backend
│   ├── routers/      # Endpoints API
│   ├── models.py     # Modèles SQLAlchemy
│   └── main.py       # Point d'entrée
├── worker/           # Celery workers
│   ├── tasks/        # Tâches async
│   └── classifiers/  # Classificateurs LLM
├── shared/           # Code partagé
├── config/           # Configurations
├── scripts/          # Scripts utilitaires
└── tests/            # Tests
```

## Guidelines de code

### Python

```python
# Typage
def process_email(email_id: int) -> Dict[str, Any]:
    """Process an email and return results."""
    pass

# Docstrings
def classify(text: str) -> str:
    """
    Classify email text.
    
    Args:
        text: Email body text
        
    Returns:
        Category name
    """
    pass

# Logging
import logging
logger = logging.getLogger(__name__)

logger.info("Processing started")
logger.error("Error occurred", exc_info=True)
```

### Tests

```python
import pytest

def test_classification():
    """Test email classification."""
    result = classify_email("test email")
    assert result['category'] is not None
    assert 0 <= result['confidence'] <= 100
```

## Domaines d'amélioration

### Fonctionnalités prioritaires

1. **Connecteurs email**
   - Implémenter IMAP complet
   - Support Microsoft Graph API
   - Support Gmail API OAuth

2. **Classification**
   - Fine-tuning du modèle
   - Règles personnalisables
   - Apprentissage à partir des corrections

3. **Interface utilisateur**
   - Dashboard web
   - Mobile app
   - Extension browser

4. **Intégrations**
   - Zapier/n8n
   - API publique
   - Webhooks

### Bugs connus

Voir [Issues](https://github.com/VOTRE-USERNAME/email-agent/issues)

## Questions ?

- 💬 [Discussions GitHub](https://github.com/VOTRE-USERNAME/email-agent/discussions)
- 🐛 [Issues](https://github.com/VOTRE-USERNAME/email-agent/issues)
- 📧 Email : votre.email@example.com

## Code of Conduct

- Soyez respectueux et professionnel
- Acceptez les critiques constructives
- Concentrez-vous sur ce qui est mieux pour la communauté

Merci de contribuer ! 🚀
