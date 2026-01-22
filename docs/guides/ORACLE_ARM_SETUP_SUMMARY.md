# ✅ Configuration Oracle ARM - Résumé

Récapitulatif de la configuration optimale pour Oracle Cloud ARM Free Tier.

---

## 📦 Fichiers créés

### Configuration Docker

| Fichier | Description | Optimisations |
|---------|-------------|---------------|
| `docker-compose.oracle-arm.yml` | Compose principal ARM | • 4 workers Celery (1 par core)<br>• Limites mémoire adaptées<br>• Platform: linux/arm64<br>• Health checks configurés |
| `config/postgresql-arm.conf` | Config PostgreSQL | • shared_buffers: 2GB<br>• effective_cache_size: 6GB<br>• 4 workers parallèles<br>• Optimisations ARM |

### Configuration Environnement

| Fichier | Description | Variables clés |
|---------|-------------|----------------|
| `.env.oracle-arm` | Template configuration | • ARM_OPTIMIZED=true<br>• CELERY_WORKERS=4<br>• OLLAMA_TIMEOUT=150<br>• Batch processing configuré |

### Scripts

| Fichier | Description | Fonctionnalités |
|---------|-------------|-----------------|
| `scripts/deploy-oracle-arm.sh` | Déploiement automatique | • Vérifications système<br>• Build ARM images<br>• Config auto<br>• Téléchargement Mistral |

### Documentation

| Fichier | Description | Contenu |
|---------|-------------|---------|
| `docs/DEPLOY_ORACLE_ARM.md` | Guide complet | • Création instance OCI<br>• Installation pas-à-pas<br>• Monitoring<br>• Dépannage |
| `ORACLE_ARM_QUICK_REF.md` | Référence rapide | • Commandes essentielles<br>• Diagnostic rapide<br>• Checklist |

---

## 🎯 Architecture déployée

### Services et ressources

```yaml
Services (11 conteneurs) :
  api:          1 GB RAM,  1 CPU   # FastAPI
  worker-1:     1 GB RAM,  1 CPU   # Celery
  worker-2:     1 GB RAM,  1 CPU   # Celery
  worker-3:     1 GB RAM,  1 CPU   # Celery
  worker-4:     1 GB RAM,  1 CPU   # Celery
  scheduler:  512 MB RAM, 0.5 CPU  # Celery Beat
  db:           4 GB RAM,  2 CPU   # PostgreSQL
  redis:        2 GB RAM,  1 CPU   # Cache + Queue
  ollama:       8 GB RAM,  2 CPU   # LLM Mistral
  nginx:      256 MB RAM, 0.5 CPU  # Reverse proxy
  portainer:  256 MB RAM, 0.5 CPU  # UI Docker

Total utilisé: ~12 GB / 24 GB (50%)
Total CPU:     ~10.5 / 4 cores (avec partage)
```

### Réseau

```
Internet
    ↓
[Oracle Cloud Security List]
    ↓
[Nginx :80, :443]
    ↓
[API :8000]
    ↓
[email-agent-network]
    ├── Workers (4x)
    ├── Scheduler
    ├── PostgreSQL
    ├── Redis
    └── Ollama
```

---

## ⚙️ Optimisations ARM appliquées

### 1. Docker Compose

**Workers parallèles (4 cores) :**
```yaml
worker-1, worker-2, worker-3, worker-4:
  deploy:
    resources:
      limits:
        memory: 1G
        cpus: '1'
  command: celery ... --concurrency=1
```

**PostgreSQL optimisé :**
```yaml
db:
  environment:
    - POSTGRES_SHARED_BUFFERS=2GB
    - POSTGRES_EFFECTIVE_CACHE_SIZE=6GB
    - POSTGRES_MAX_WORKER_PROCESSES=4
    - POSTGRES_MAX_PARALLEL_WORKERS=4
  deploy:
    resources:
      limits:
        memory: 4G
        cpus: '2'
```

**Ollama ARM64 :**
```yaml
ollama:
  platform: linux/arm64
  environment:
    - OLLAMA_NUM_PARALLEL=2
    - OLLAMA_MAX_LOADED_MODELS=1
  deploy:
    resources:
      limits:
        memory: 8G
        cpus: '2'
```

### 2. Configuration PostgreSQL (postgresql-arm.conf)

**Mémoire :**
- `shared_buffers = 2GB` (1/12 de 24GB)
- `effective_cache_size = 6GB` (1/4 de 24GB)
- `work_mem = 64MB`
- `maintenance_work_mem = 512MB`

**Parallélisme :**
- `max_worker_processes = 4`
- `max_parallel_workers_per_gather = 2`
- `max_parallel_workers = 4`

**I/O ARM :**
- `random_page_cost = 1.1` (SSD)
- `effective_io_concurrency = 200`

### 3. Configuration Environnement (.env)

**ARM spécifique :**
```bash
ARM_OPTIMIZED=true
PLATFORM=arm64
```

**Workers :**
```bash
CELERY_WORKERS=4
CELERY_WORKER_CONCURRENCY=1
MAX_CONCURRENT_CLASSIFICATIONS=4
```

**Timeouts adaptés ARM :**
```bash
OLLAMA_TIMEOUT=150
CLASSIFICATION_TIMEOUT=150
IMAP_TIMEOUT=90
```

**Batch processing :**
```bash
EMAIL_SYNC_BATCH_SIZE=1000
CLASSIFICATION_BATCH_SIZE=100
MAX_EMAILS_PER_SYNC=2000
```

**Stratégie hybride :**
```bash
CLASSIFICATION_STRATEGY=hybrid
RULES_FIRST=true
AI_ONLY_FOR_UNCERTAIN=true
```

---

## 📊 Performance attendue

### Benchmarks 20K emails

| Phase | Stratégie | Temps | Explications |
|-------|-----------|-------|--------------|
| **Fetch IMAP** | Batch 1000 | 10-20 min | Téléchargement réseau |
| **Parse emails** | Streaming | 5 min | Parse MIME + DB insert |
| **Règles YAML** | 14K emails | 5 min | ~70% emails (instant) |
| **IA Ollama** | 6K emails | 45-90 min | ~30% emails (2-3 sec/email) |
| **Actions** | Batch | 5 min | Move/archive emails |
| **TOTAL** | Hybride | **1-2 heures** | Premier traitement complet |

### Mode continu (après initial sync)

| Métrique | Valeur | Détails |
|----------|--------|---------|
| **Sync interval** | 10 min | Configurable |
| **Nouveaux emails** | 50-100/sync | Typique |
| **Classification** | 2-3 emails/sec | 4 workers parallèles |
| **Latence API** | < 100ms | Réponses rapides |
| **RAM utilisée** | 10-12 GB | 50% disponible |
| **CPU moyen** | 30-40% | 60% en pic |

### Scalabilité

| Inbox Size | Temps initial | RAM | Faisabilité |
|------------|---------------|-----|-------------|
| **5K emails** | 20-30 min | 8 GB | ✅ Excellent |
| **10K emails** | 30-60 min | 10 GB | ✅ Très bon |
| **20K emails** | 1-2 heures | 12 GB | ✅ Bon |
| **50K emails** | 3-6 heures | 14 GB | ⚠️ Limite |
| **100K emails** | 8-12 heures | 16 GB | ❌ Progressif requis |

---

## 🔧 Stratégies de traitement

### 1. Sync Complète (< 20K emails)

```bash
# .env
ENABLE_PROGRESSIVE_SYNC=false
MAX_EMAILS_PER_SYNC=20000

# Traite tout d'un coup
# Temps: 1-2 heures
# RAM: 12 GB
```

### 2. Sync Progressive (20K-100K emails)

```bash
# .env
ENABLE_PROGRESSIVE_SYNC=true
INITIAL_SYNC_DAYS=30
PROGRESSIVE_SYNC_DAYS=90,180,365,all

# Jour 1: Derniers 30 jours (500-2000 emails)
# Jour 2-7: Extension progressive
# Temps total: 1 semaine (background)
# RAM: 10-12 GB
```

### 3. Stratégie Hybride (optimal)

```bash
# .env
CLASSIFICATION_STRATEGY=hybrid
RULES_FIRST=true
AI_ONLY_FOR_UNCERTAIN=true

# 70% emails: Règles YAML (instant)
# 30% emails: IA Ollama (lent)
# Gain: 60-70% temps économisé
```

---

## ✅ Checklist validation

### Post-déploiement

- [ ] Tous les services "Up" (`docker compose ps`)
- [ ] API répond (`curl localhost:8000/health`)
- [ ] PostgreSQL healthy (`pg_isready`)
- [ ] Redis répond (`redis-cli ping`)
- [ ] Ollama Mistral téléchargé (`ollama list`)
- [ ] 4 workers actifs (`celery inspect active`)
- [ ] Scheduler actif (`celery inspect scheduled`)
- [ ] RAM < 50% utilisée (`free -h`)
- [ ] Logs sans erreurs (`docker compose logs`)

### Fonctionnel

- [ ] Compte email ajouté
- [ ] Première synchronisation lancée
- [ ] Emails visibles dans DB
- [ ] Classification fonctionne
- [ ] Actions exécutées (move/label)
- [ ] API endpoints répondent
- [ ] Portainer accessible (optionnel)

### Performance

- [ ] Classification < 3 sec/email
- [ ] API latence < 100ms
- [ ] Sync complète < 2h (20K emails)
- [ ] CPU moyen < 50%
- [ ] Pas de memory leak (stable)

---

## 🚀 Commandes de déploiement complètes

### Depuis zéro (instance Oracle ARM)

```bash
# 1. Update système
sudo apt update && sudo apt upgrade -y

# 2. Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu
exit  # Reconnect

# 3. Install Docker Compose
sudo apt install -y docker-compose-plugin

# 4. Clone repository
git clone https://github.com/your-username/email-agent.git
cd email-agent

# 5. Configure
cp .env.oracle-arm .env
nano .env  # Changer tous les CHANGEME

# 6. Générer clés
openssl rand -hex 32
python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"

# 7. Deploy automatique
./scripts/deploy-oracle-arm.sh

# 8. Vérifier
docker compose -f docker-compose.oracle-arm.yml ps
curl http://localhost:8000/health

# 9. Ajouter compte
docker compose -f docker-compose.oracle-arm.yml exec api python scripts/add_email_account.py

# 10. Surveiller
docker compose -f docker-compose.oracle-arm.yml logs -f worker-1
```

**Temps total : 20-30 minutes**

---

## 📈 Monitoring production

### Commandes essentielles

```bash
# Stats temps réel
docker stats

# Health check API
curl http://localhost:8000/health

# Workers actifs
docker compose -f docker-compose.oracle-arm.yml exec worker-1 \
  celery -A worker.celery_app inspect active

# Emails traités
docker compose -f docker-compose.oracle-arm.yml exec db \
  psql -U emailagent -d emailagent -c \
  "SELECT COUNT(*) FROM emails WHERE status='classified';"

# Performance classification
docker compose -f docker-compose.oracle-arm.yml exec db \
  psql -U emailagent -d emailagent -c \
  "SELECT AVG(processing_time_ms) FROM emails WHERE processed_at > NOW() - INTERVAL '1 hour';"
```

### Alertes recommandées

```bash
# RAM > 90%
free | awk '/^Mem:/ {if ($3/$2 > 0.90) print "ALERT: RAM usage > 90%"}'

# Disque > 80%
df / | awk 'NR==2 {if ($5+0 > 80) print "ALERT: Disk usage > 80%"}'

# Services down
docker compose -f docker-compose.oracle-arm.yml ps --filter "status=exited"
```

---

## 🎉 Résultat final

**Système complet prêt pour :**
- ✅ 20 000+ emails existants
- ✅ Classification intelligente (IA Ollama)
- ✅ Multi-comptes (Gmail, Outlook, IMAP)
- ✅ Performance optimale ARM
- ✅ 0€ de coût (Always Free)
- ✅ Scalable et maintenable
- ✅ Monitoring et logs complets
- ✅ Backup et sécurité

**Infrastructure professionnelle sur Oracle Cloud gratuit ! 🚀**

---

**Version** : 1.0.0
**Date** : 2025-01-21
**Testé** : Oracle ARM Ampere A1, 24GB, 4 OCPUs
