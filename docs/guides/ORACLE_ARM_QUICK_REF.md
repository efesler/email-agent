# ⚡ Oracle ARM - Référence Rapide

Guide ultra-rapide pour déployer et gérer Email Agent AI sur Oracle Cloud ARM Free Tier.

---

## 🎯 Spécifications

| Ressource | Oracle ARM Free Tier | Performance 20K emails |
|-----------|---------------------|------------------------|
| **Coût** | 0€ Always Free | ✅ Gratuit |
| **RAM** | 24 GB | ✅ 12 GB utilisés (50%) |
| **CPU** | 4 OCPUs ARM | ✅ 60-80% pendant classification |
| **Disque** | 200 GB | ✅ ~20-30 GB utilisés |
| **Temps classification** | - | ✅ 1-2h (20K emails) |
| **Débit continu** | - | ✅ 2-3 emails/sec |

---

## 🚀 Déploiement en 5 commandes

### Sur votre instance Oracle ARM

```bash
# 1. Clone
git clone https://github.com/your-username/email-agent.git
cd email-agent

# 2. Configure
cp .env.oracle-arm .env
nano .env  # Changez tous les CHANGEME

# 3. Générer clés sécurisées
openssl rand -hex 32  # SECRET_KEY
python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"  # ENCRYPTION_KEY

# 4. Deploy (15-30 min)
./scripts/deploy-oracle-arm.sh

# 5. Ajouter compte email
docker compose -f docker-compose.oracle-arm.yml exec api python scripts/add_email_account.py
```

**C'est tout ! 🎉**

---

## 📋 Commandes essentielles

### Gestion services

| Action | Commande |
|--------|----------|
| **Status** | `docker compose -f docker-compose.oracle-arm.yml ps` |
| **Logs** | `docker compose -f docker-compose.oracle-arm.yml logs -f` |
| **Restart** | `docker compose -f docker-compose.oracle-arm.yml restart` |
| **Stop** | `docker compose -f docker-compose.oracle-arm.yml down` |
| **Start** | `docker compose -f docker-compose.oracle-arm.yml up -d` |

### Monitoring

| Métrique | Commande |
|----------|----------|
| **Stats Docker** | `docker stats` |
| **RAM** | `free -h` |
| **CPU** | `htop` |
| **Disque** | `df -h` |
| **API Health** | `curl http://localhost:8000/health` |

### Gestion emails

| Action | Commande |
|--------|----------|
| **Ajouter compte** | `docker compose -f docker-compose.oracle-arm.yml exec api python scripts/add_email_account.py` |
| **Lister comptes** | `docker compose -f docker-compose.oracle-arm.yml exec api python scripts/add_email_account.py list` |
| **Logs sync** | `docker compose -f docker-compose.oracle-arm.yml logs -f worker-1` |

### Database

| Action | Commande |
|--------|----------|
| **Backup** | `docker compose -f docker-compose.oracle-arm.yml exec db pg_dump -U emailagent emailagent > backup.sql` |
| **Restore** | `cat backup.sql \| docker compose -f docker-compose.oracle-arm.yml exec -T db psql -U emailagent emailagent` |
| **Console** | `docker compose -f docker-compose.oracle-arm.yml exec db psql -U emailagent -d emailagent` |

---

## 🔧 Configuration optimale (dans .env)

### Pour grandes inbox (20K+)

```bash
# Sync progressive
ENABLE_PROGRESSIVE_SYNC=true
INITIAL_SYNC_DAYS=30
PROGRESSIVE_SYNC_DAYS=90,180,365,all

# Classification hybride (vitesse)
CLASSIFICATION_STRATEGY=hybrid
RULES_FIRST=true
AI_ONLY_FOR_UNCERTAIN=true

# Batch processing
EMAIL_SYNC_BATCH_SIZE=1000
CLASSIFICATION_BATCH_SIZE=100
MAX_EMAILS_PER_SYNC=2000

# Workers (4 cores ARM)
CELERY_WORKERS=4
CELERY_WORKER_CONCURRENCY=1
MAX_CONCURRENT_CLASSIFICATIONS=4

# Timeouts ARM
OLLAMA_TIMEOUT=150
CLASSIFICATION_TIMEOUT=150
IMAP_TIMEOUT=90
```

---

## 📊 Architecture déployée

```
┌─────────────────────────────────────────────────┐
│ Oracle Cloud ARM Instance (24GB, 4 cores)       │
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐     │
│  │  API     │  │  Nginx   │  │Portainer │     │
│  │  1GB     │  │  256MB   │  │  256MB   │     │
│  └──────────┘  └──────────┘  └──────────┘     │
│                                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐     │
│  │Worker 1  │  │Worker 2  │  │Worker 3  │     │
│  │  1GB     │  │  1GB     │  │  1GB     │     │
│  └──────────┘  └──────────┘  └──────────┘     │
│                                                 │
│  ┌──────────┐  ┌──────────┐                   │
│  │Worker 4  │  │Scheduler │                   │
│  │  1GB     │  │  512MB   │                   │
│  └──────────┘  └──────────┘                   │
│                                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐     │
│  │PostgreSQL│  │  Redis   │  │  Ollama  │     │
│  │   4GB    │  │   2GB    │  │   8GB    │     │
│  └──────────┘  └──────────┘  └──────────┘     │
│                                                 │
│  Total utilisé: ~12GB / 24GB (50%)             │
└─────────────────────────────────────────────────┘
```

---

## ⚡ Performance attendue

### Synchronisation initiale (20K emails)

| Phase | Stratégie | Temps | RAM | CPU |
|-------|-----------|-------|-----|-----|
| **Fetch IMAP** | Batch 1000 | 10-20 min | 2 GB | 30% |
| **Règles YAML** | 70% emails | 5 min | 1 GB | 20% |
| **IA Ollama** | 30% emails | 45-90 min | 8 GB | 80% |
| **Total** | Hybride | **1-2h** | **12 GB** | **60%** |

### Mode continu

| Métrique | Valeur |
|----------|--------|
| **Sync interval** | 10 minutes |
| **Nouveaux emails** | ~50-100 par sync |
| **Classification** | 2-3 emails/sec |
| **Latence API** | < 100ms |
| **RAM moyenne** | 10-12 GB |
| **CPU moyen** | 30-40% |

---

## 🔍 Diagnostic rapide

### Service ne démarre pas

```bash
# 1. Vérifier logs
docker compose -f docker-compose.oracle-arm.yml logs <service>

# 2. Vérifier ressources
free -h && df -h

# 3. Rebuild
docker compose -f docker-compose.oracle-arm.yml build <service>
docker compose -f docker-compose.oracle-arm.yml up -d
```

### Classification lente

```bash
# 1. Vérifier Ollama
docker compose -f docker-compose.oracle-arm.yml logs ollama

# 2. Vérifier workers actifs
docker compose -f docker-compose.oracle-arm.yml exec worker-1 celery -A worker.celery_app inspect active

# 3. Augmenter timeout dans .env
OLLAMA_TIMEOUT=180
```

### Manque de RAM

```bash
# 1. Stats mémoire
docker stats --no-stream

# 2. Réduire Ollama (si nécessaire)
# Éditer docker-compose.oracle-arm.yml:
#   ollama.deploy.resources.limits.memory: 6G

# 3. Restart
docker compose -f docker-compose.oracle-arm.yml restart ollama
```

---

## 📁 Structure fichiers importante

```
email-agent/
├── .env                              # ⚠️ CONFIG PRINCIPALE (à créer)
├── .env.oracle-arm                   # Template configuration ARM
├── docker-compose.oracle-arm.yml    # 🚀 Compose pour ARM
├── config/
│   └── postgresql-arm.conf          # Config PostgreSQL optimisée
├── scripts/
│   └── deploy-oracle-arm.sh         # 🎯 Script déploiement auto
└── docs/
    └── DEPLOY_ORACLE_ARM.md         # 📖 Guide complet
```

---

## 🎯 Checklist déploiement

- [ ] Instance Oracle ARM créée (4 OCPUs, 24 GB)
- [ ] Ports ouverts (22, 80, 443, 8000, 9000)
- [ ] Docker + Docker Compose installés
- [ ] Repository cloné
- [ ] `.env` configuré (tous les CHANGEME changés)
- [ ] Clés générées (SECRET_KEY, ENCRYPTION_KEY)
- [ ] `deploy-oracle-arm.sh` exécuté avec succès
- [ ] Tous les services "Up" (docker compose ps)
- [ ] API répond (curl localhost:8000/health)
- [ ] Ollama Mistral téléchargé (ollama list)
- [ ] Premier compte email ajouté
- [ ] Première synchronisation OK (logs worker)

---

## 🔗 Liens rapides

| Service | URL |
|---------|-----|
| **API** | `http://<IP>:8000` |
| **API Docs** | `http://<IP>:8000/docs` |
| **Health** | `http://<IP>:8000/health` |
| **Portainer** | `http://<IP>:9000` |

---

## 📞 Support

**Documentation complète :**
- 📘 [Guide déploiement détaillé](docs/DEPLOY_ORACLE_ARM.md)
- 🚀 [Guide rapide général](GUIDE_RAPIDE.md)
- 📧 [Ajouter compte email](ADD_EMAIL_ACCOUNT.md)

**Logs :**
```bash
docker compose -f docker-compose.oracle-arm.yml logs -f
```

---

**Tout est prêt pour 20K+ emails ! 🚀**

**Version** : 1.0.0 | **Oracle ARM Free Tier** : 24GB, 4 OCPUs
