# 🤖 Guides AI Coding Agents - Email Agent AI

## 📋 Nouveaux fichiers ajoutés

Deux fichiers essentiels pour maximiser l'efficacité des AI coding agents ont été ajoutés au projet :

### 1. CLAUDE.md (17 KB)
**Guide spécialisé pour Claude Code et assistants Claude**

Optimisé pour les capacités spécifiques de Claude avec :
- Contexte complet du projet
- Architecture détaillée avec diagrammes ASCII
- TODOs prioritaires avec code starter
- Exemples de code complets
- Patterns spécifiques FastAPI/SQLAlchemy
- Instructions de debug détaillées
- Tips spécifiques pour Claude

### 2. AGENT.md (14 KB)
**Guide universel pour tous les AI coding agents**

Compatible avec GitHub Copilot, Cursor, Cody, Tabnine, etc.
- Vue d'ensemble technique concise
- Conventions de code strictes
- Patterns communs avec exemples
- Pièges fréquents à éviter
- Documentation des APIs
- Quick reference pour démarrer

## 🎯 Pourquoi ces fichiers ?

### Problème résolu
Sans ces guides, les AI agents doivent :
- ❌ Deviner l'architecture du projet
- ❌ Chercher les conventions de code
- ❌ Comprendre le contexte petit à petit
- ❌ Potentiellement créer du code incohérent

Avec ces guides :
- ✅ Context complet dès le départ
- ✅ Code cohérent avec le projet
- ✅ Productivité maximale
- ✅ Moins d'erreurs et d'allers-retours

### Différences entre CLAUDE.md et AGENT.md

| Aspect | CLAUDE.md | AGENT.md |
|--------|-----------|----------|
| **Longueur** | 17 KB (très détaillé) | 14 KB (concis) |
| **Style** | Conversationnel, tips "Claude" | Factuel, technique |
| **Exemples** | Très nombreux avec explications | Code snippets essentiels |
| **Public** | Claude Code, Claude API | Tous les AI agents |
| **Debug** | Section extensive | Section minimale |
| **TODOs** | Avec code starter complet | Liste prioritaire |

## 📖 Comment les AI agents utilisent ces fichiers

### Avec Claude Code
```bash
# Claude lit automatiquement CLAUDE.md quand vous demandez :
"Implémente la connexion IMAP dans worker/tasks/email_sync.py"

# Claude sait alors :
- Structure exacte du projet
- Conventions à respecter
- Code starter à utiliser
- Où logger, comment tester
- Patterns DB async à suivre
```

### Avec GitHub Copilot / Cursor
```python
# Quand vous tapez un commentaire :
# TODO: Implement Gmail OAuth flow

# Copilot suggère du code cohérent basé sur AGENT.md
# Respecte les conventions (type hints, async/await, logging)
```

### Avec Cody / Tabnine
```bash
# Question à Cody :
"How do I add a new API endpoint?"

# Cody répond basé sur AGENT.md section "Common Patterns"
# Avec exemple exact adapté au projet
```

## 🔥 Contenu clé de CLAUDE.md

### 1. Architecture complète
```
┌─────────────────┐
│  Email Accounts │
│  (IMAP/Gmail)   │
└────────┬────────┘
         │
    ┌────▼─────┐      ┌──────────┐
    │  Worker  │─────►│  Ollama  │
    │ (Celery) │      │   (LLM)  │
    └────┬─────┘      └──────────┘
```

### 2. TODOs avec code starter
```python
# Priority 1: IMAP Connector
async def sync_account(account_id: int):
    """
    TODO: Implement IMAP connection
    
    Steps:
    1. Get EmailAccount from DB
    2. Decrypt credentials
    3. Connect via IMAPClient
    ...
    
    Code starter provided
    Dependencies listed
    """
```

### 3. Patterns spécifiques
```python
# Database async pattern
async with get_db_context() as db:
    email = await db.get(Email, email_id)
    
# Celery task pattern
@shared_task(name='worker.tasks.example.task')
def my_task(item_id: int) -> dict:
    # Always return dict with status
```

### 4. Debug instructions
```bash
# Logs
docker-compose logs -f api

# Shell
docker-compose exec api python

# Tests
make test
```

## 🎯 Contenu clé de AGENT.md

### 1. Quick overview
```yaml
Language: Python 3.11+
Framework: FastAPI
Database: PostgreSQL (async SQLAlchemy)
Queue: Celery + Redis
AI: Ollama (Mistral 7B)
```

### 2. Code guidelines
```python
# Type hints mandatory
def func(x: int) -> str:
    pass

# Async for DB
async def get_item(db: AsyncSession):
    pass
    
# Logging everywhere
logger.info("Message")
```

### 3. Common pitfalls
```python
# ❌ WRONG
def get_email():
    email = db.query(Email).get(1)
    
# ✅ CORRECT
async def get_email(db: AsyncSession):
    email = await db.get(Email, 1)
```

### 4. Priority TODOs
1. Email connectors (HIGH)
2. OAuth2 flows (HIGH)
3. Web UI (MEDIUM)
4. OCR (LOW)

## 💡 Cas d'usage pratiques

### Scénario 1 : Nouvelle feature
```
User: "Claude, implémente la connexion Gmail OAuth"

Claude lit CLAUDE.md:
- Trouve section "Priority 2: OAuth2"
- Voit le code starter
- Connaît les dépendances (google-api-python-client)
- Sait où créer le fichier (api/routers/oauth.py)
- Respecte les conventions (async, logging, error handling)
- Crée tests appropriés

Résultat: Code cohérent et complet en une passe
```

### Scénario 2 : Bug fix
```
User: "Fix l'erreur dans email_sync.py"

Claude:
- Lit CLAUDE.md section "Debug"
- Vérifie logs avec commandes suggérées
- Comprend architecture pour identifier le problème
- Applique patterns corrects
- Ajoute logs pour éviter le bug futur

Résultat: Fix propre avec debugging amélioré
```

### Scénario 3 : Refactoring
```
User: "Refactor le classificateur pour supporter plus de catégories"

Claude:
- Lit structure DB dans CLAUDE.md
- Voit enum EmailCategory
- Comprend flow de classification
- Connaît patterns Pydantic/SQLAlchemy
- Update modèles, API, et worker de façon cohérente

Résultat: Refactoring complet et cohérent
```

## 🚀 Optimiser l'utilisation

### Pour Claude Code
```bash
# En début de session
"Lis CLAUDE.md pour comprendre le projet"

# Avant chaque feature
"Réfère-toi à CLAUDE.md section TODOs"

# En cas d'erreur
"Consulte CLAUDE.md section Debug"
```

### Pour autres AI agents
```bash
# Configurer l'agent pour lire AGENT.md
# Exemple avec Cursor:
# Settings → Features → Context Files → Add "AGENT.md"

# Puis simplement coder
# L'agent utilisera AGENT.md comme référence
```

## 📊 Impact attendu sur productivité

### Sans les guides
- ⏱️ 30+ min pour comprendre l'architecture
- 🐛 2-3 allers-retours pour code cohérent
- ❓ Questions fréquentes sur conventions
- 🔄 Refactoring nécessaire souvent

### Avec les guides
- ⚡ 2-3 min pour context complet
- ✅ Code cohérent du premier coup
- 📚 Auto-documentation
- 🎯 Focus sur la feature, pas sur le setup

**Gain estimé : 40-60% de temps** sur nouvelles features

## 🎁 Bonus : Prompts optimisés

### Prompts pour Claude Code avec CLAUDE.md

```
# Nouveau endpoint
"En suivant CLAUDE.md, crée un endpoint GET /api/stats/weekly 
qui retourne les stats hebdomadaires"

# Implémentation TODO
"Implémente le TODO Priority 1 dans CLAUDE.md section Email Connectors.
Commence par worker/tasks/email_sync.py"

# Debug
"L'email sync échoue. Utilise CLAUDE.md section Debug pour identifier 
le problème et proposer un fix"

# Tests
"Crée des tests pour le nouveau classificateur en suivant 
les patterns de CLAUDE.md section Tests"
```

### Prompts génériques pour autres agents

```
# Context
"Read AGENT.md and understand the project structure"

# Code
"Following AGENT.md conventions, implement IMAP connection"

# Fix
"The async DB call is failing. Check AGENT.md Common Pitfalls"

# Pattern
"Show me the correct pattern for creating a new Celery task 
based on AGENT.md"
```

## ✅ Résumé

Ces deux fichiers transforment le projet d'une "collection de code" en un **"projet prêt pour AI agents"**.

### Bénéfices immédiats
- 🚀 Onboarding instantané pour AI agents
- 💯 Code cohérent dès le départ
- 📚 Documentation auto-référencée
- ⚡ Productivité maximale

### Bénéfices long-terme
- 🔄 Maintenance facilitée
- 👥 Nouveaux contributeurs guidés
- 📈 Qualité de code consistante
- 🎓 Apprentissage accéléré

**Votre projet est maintenant optimisé pour le développement assisté par IA ! 🤖✨**

---

*Guides créés le 2025-01-20*  
*Version: 1.0.0*  
*Compatible: Claude Code, GitHub Copilot, Cursor, Cody, Tabnine*
