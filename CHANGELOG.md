# Changelog

Tous les changements notables de ce projet seront documentés dans ce fichier.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/),
et ce projet adhère au [Semantic Versioning](https://semver.org/lang/fr/).

## [Unreleased]

### À venir
- Connecteur IMAP complet
- Interface web (dashboard React)
- OAuth2 Gmail et Microsoft
- Fine-tuning du modèle Ollama
- Application mobile

## [1.0.0] - 2025-01-20

### 🎉 Release initiale

#### Ajouté
- **Infrastructure complète**
  - Docker Compose pour production (Oracle Cloud) et développement
  - PostgreSQL 15 avec optimisations ARM
  - Redis pour cache et queue
  - Ollama pour LLM local (Mistral 7B)
  - Nginx reverse proxy avec support SSL

- **API FastAPI**
  - Endpoints authentification (`/api/auth`)
  - Gestion comptes email (`/api/accounts`)
  - Consultation emails (`/api/emails`)
  - Classification (`/api/classification`)
  - Statistiques (`/api/stats`)
  - Health checks et monitoring

- **Worker Celery**
  - Tâches asynchrones pour sync emails
  - Classification automatique avec Ollama
  - Scheduler pour polling périodique
  - Tâches de maintenance (cleanup, stats)

- **Classificateur IA**
  - Prompt engineering optimisé pour Ollama
  - Support de 11 catégories d'emails
  - Scoring de confiance
  - Explication des classifications
  - Règles YAML personnalisables

- **Modèles de données**
  - Users et organisations
  - EmailAccounts multi-comptes
  - Emails avec métadonnées complètes
  - EmailAttachments
  - ClassificationRules
  - ProcessingLogs pour audit

- **Scripts d'installation**
  - `setup-oracle.sh` : Installation one-click Oracle Cloud
  - `setup-ollama.sh` : Setup automatique du LLM
  - `backup.sh` et `restore.sh` : Gestion des backups
  - `pre-deployment-check.sh` : Vérifications pré-deploy

- **Documentation**
  - README.md exhaustif avec exemples
  - QUICKSTART.md pour Oracle Cloud
  - CONTRIBUTING.md pour contributeurs
  - CODE_OF_CONDUCT.md
  - SECURITY.md avec politique de sécurité

- **DevOps**
  - Makefile avec commandes utiles
  - GitHub Actions pour CI/CD
  - Docker Compose dev avec hot reload
  - Templates d'issues et PR

#### Sécurité
- Chiffrement des credentials avec Fernet
- Génération automatique de clés secrètes
- Configuration UFW firewall
- Fail2Ban pour protection SSH
- Support SSL/HTTPS avec Certbot

#### Performance
- Optimisations PostgreSQL pour ARM
- Caching Redis
- Traitement async avec Celery
- Pool de connexions optimisé
- Compression Nginx

### Notes de migration

Première version - pas de migration nécessaire.

### Crédits

Développé avec ❤️ pour la communauté open-source.

---

[Unreleased]: https://github.com/VOTRE-USERNAME/email-agent/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/VOTRE-USERNAME/email-agent/releases/tag/v1.0.0
