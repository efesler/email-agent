# 🚀 Déploiement sur Oracle Cloud ARM Free Tier

Guide complet pour déployer Email Agent AI sur Oracle Cloud Infrastructure (OCI) avec ARM Ampere A1.

---

## 🎯 Spécifications Oracle ARM Free Tier

| Ressource | Disponible | Coût |
|-----------|------------|------|
| **Instance** | Ampere A1 | 0€ Always Free |
| **OCPUs** | 4 cores ARM | 0€ Always Free |
| **RAM** | 24 GB | 0€ Always Free |
| **Stockage** | 200 GB Boot Volume | 0€ Always Free |
| **Trafic** | 10 TB/mois | 0€ Always Free |
| **IP publique** | 2 IPv4 | 0€ Always Free |

**Performance attendue pour 20K emails :**
- Temps de classification complète : 1-2 heures
- Classification continue : 2-3 emails/sec
- RAM utilisée : ~12 GB / 24 GB (50%)
- CPU utilisé : 60-80% pendant classification

---

## 📋 Prérequis

### 1. Compte Oracle Cloud

1. Créer un compte sur https://www.oracle.com/cloud/free/
2. Activer le Always Free Tier
3. Vérifier email et activer compte

### 2. Créer une instance ARM

**Compute → Instances → Create Instance**

```yaml
Name: email-agent-arm
Image: Ubuntu 22.04 ARM64
Shape: VM.Standard.A1.Flex
  OCPUs: 4
  Memory: 24 GB
Boot Volume: 200 GB
Network: Default VCN
SSH Keys: Upload your public key
```

### 3. Configuration réseau (Security List)

**Ouvrir les ports nécessaires :**

| Port | Protocol | Source | Description |
|------|----------|--------|-------------|
| 22 | TCP | 0.0.0.0/0 | SSH |
| 80 | TCP | 0.0.0.0/0 | HTTP |
| 443 | TCP | 0.0.0.0/0 | HTTPS |
| 8000 | TCP | 0.0.0.0/0 | API (temporaire) |
| 9000 | TCP | VoIP IP/32 | Portainer (optionnel) |

**Commandes sur l'instance :**
```bash
# Ouvrir les ports dans le firewall Ubuntu
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 8000/tcp
sudo ufw enable
```

---

## 🔧 Installation pas-à-pas

### Étape 1 : Connexion SSH

```bash
# Depuis votre machine locale
ssh -i ~/.ssh/your-key.pem ubuntu@<INSTANCE_PUBLIC_IP>
```

### Étape 2 : Mise à jour système

```bash
# Update packages
sudo apt update && sudo apt upgrade -y

# Install basics
sudo apt install -y git curl wget nano htop

# Vérifier architecture
uname -m  # Doit afficher: aarch64
```

### Étape 3 : Installation Docker ARM

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Ajouter utilisateur au groupe docker
sudo usermod -aG docker ubuntu

# Déconnexion/reconnexion pour appliquer
exit
# Reconnectez-vous via SSH

# Vérifier Docker
docker --version
docker run --rm hello-world

# Install Docker Compose
sudo apt install -y docker-compose-plugin

# Vérifier
docker compose version
```

### Étape 4 : Cloner le repository

```bash
# Clone
git clone https://github.com/your-username/email-agent.git
cd email-agent

# Ou upload via SCP
# scp -i ~/.ssh/key.pem -r email-agent ubuntu@<IP>:/home/ubuntu/
```

### Étape 5 : Configuration

```bash
# Copier template configuration
cp .env.oracle-arm .env

# Éditer configuration
nano .env

# IMPORTANT: Changer TOUS les "CHANGEME"
# Utiliser des mots de passe forts!
```

**Génération des clés sécurisées :**

```bash
# SECRET_KEY (32 bytes hex)
openssl rand -hex 32

# ENCRYPTION_KEY (Fernet)
python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"

# Coller dans .env
```

### Étape 6 : Déploiement automatique

```bash
# Lancer le script de déploiement
./scripts/deploy-oracle-arm.sh
```

**Le script effectue automatiquement :**
1. ✅ Vérification architecture ARM
2. ✅ Vérification Docker/Docker Compose
3. ✅ Vérification ressources (RAM, disque)
4. ✅ Configuration .env
5. ✅ Build images Docker ARM (10-20 min)
6. ✅ Démarrage services
7. ✅ Téléchargement Ollama Mistral ARM (5-10 min)
8. ✅ Vérification santé services

**Temps total : 15-30 minutes**

---

## ✅ Vérification post-déploiement

### 1. Vérifier les services

```bash
# Status des conteneurs
docker compose -f docker-compose.oracle-arm.yml ps

# Tous doivent être "Up" ou "Up (healthy)"
```

**Sortie attendue :**
```
NAME                      STATUS
email-agent-api           Up (healthy)
email-agent-db            Up (healthy)
email-agent-redis         Up (healthy)
email-agent-ollama        Up
email-agent-worker-1      Up
email-agent-worker-2      Up
email-agent-worker-3      Up
email-agent-worker-4      Up
email-agent-scheduler     Up
email-agent-nginx         Up
email-agent-portainer     Up
```

### 2. Tester l'API

```bash
# Health check
curl http://localhost:8000/health

# API info
curl http://localhost:8000/

# Documentation interactive
# Ouvrez dans navigateur: http://<INSTANCE_IP>:8000/docs
```

### 3. Vérifier Ollama

```bash
# Liste des modèles
docker compose -f docker-compose.oracle-arm.yml exec ollama ollama list

# Doit afficher: mistral
```

### 4. Vérifier les workers Celery

```bash
# Workers actifs
docker compose -f docker-compose.oracle-arm.yml exec worker-1 celery -A worker.celery_app inspect active

# Stats workers
docker compose -f docker-compose.oracle-arm.yml exec worker-1 celery -A worker.celery_app inspect stats
```

### 5. Monitoring ressources

```bash
# Stats Docker en temps réel
docker stats

# Mémoire système
free -h

# CPU load
htop
```

---

## 📧 Configuration premier compte email

### Méthode interactive

```bash
docker compose -f docker-compose.oracle-arm.yml exec api python scripts/add_email_account.py
```

Suivez le guide :
1. Type : Gmail (recommandé pour commencer)
2. Configurez mot de passe d'application (voir GMAIL_EXAMPLE.md)
3. Confirmez

### Vérifier synchronisation

```bash
# Logs worker en temps réel
docker compose -f docker-compose.oracle-arm.yml logs -f worker-1

# Voir les emails synchronisés
curl http://localhost:8000/api/emails/?limit=10
```

---

## 📊 Monitoring et Logs

### Logs par service

```bash
# Tous les logs
docker compose -f docker-compose.oracle-arm.yml logs -f

# Service spécifique
docker compose -f docker-compose.oracle-arm.yml logs -f api
docker compose -f docker-compose.oracle-arm.yml logs -f worker-1
docker compose -f docker-compose.oracle-arm.yml logs -f db
docker compose -f docker-compose.oracle-arm.yml logs -f ollama

# Dernières 100 lignes
docker compose -f docker-compose.oracle-arm.yml logs --tail 100 worker-1
```

### Portainer (Interface graphique)

1. Ouvrez : `http://<INSTANCE_IP>:9000`
2. Créez un compte admin
3. Connectez-vous au local Docker
4. Gérez les conteneurs visuellement

### Stats système

```bash
# Utilisation mémoire par conteneur
docker stats --no-stream

# Top processus
htop

# Espace disque
df -h

# Logs PostgreSQL
docker compose -f docker-compose.oracle-arm.yml exec db psql -U emailagent -d emailagent -c "\dt"
```

---

## 🔄 Opérations quotidiennes

### Redémarrer les services

```bash
# Redémarrer tout
docker compose -f docker-compose.oracle-arm.yml restart

# Service spécifique
docker compose -f docker-compose.oracle-arm.yml restart worker-1

# Arrêter/démarrer
docker compose -f docker-compose.oracle-arm.yml down
docker compose -f docker-compose.oracle-arm.yml up -d
```

### Mise à jour code

```bash
# Pull dernières modifications
git pull

# Rebuild images
docker compose -f docker-compose.oracle-arm.yml build

# Redémarrer avec nouvelles images
docker compose -f docker-compose.oracle-arm.yml up -d
```

### Backup base de données

```bash
# Backup manuel
docker compose -f docker-compose.oracle-arm.yml exec db pg_dump -U emailagent emailagent > backup-$(date +%Y%m%d).sql

# Restore
cat backup-20250120.sql | docker compose -f docker-compose.oracle-arm.yml exec -T db psql -U emailagent emailagent
```

### Nettoyage

```bash
# Nettoyer images inutilisées
docker system prune -a

# Nettoyer volumes (ATTENTION: perte de données)
docker volume prune

# Nettoyer logs (si trop volumineux)
sudo truncate -s 0 logs/*.log
```

---

## 🔒 Sécurité

### Bonnes pratiques

1. **Firewall** :
   ```bash
   sudo ufw status
   # Bloquer tous sauf ports nécessaires
   ```

2. **SSH** :
   - Désactiver connexion par mot de passe
   - Utiliser uniquement clés SSH
   - Changer port SSH par défaut

3. **Mots de passe** :
   - Utilisez des mots de passe forts (32+ caractères)
   - Changez les mots de passe par défaut
   - Ne commitez JAMAIS .env dans Git

4. **SSL/TLS** :
   ```bash
   # Installer Certbot pour Let's Encrypt
   sudo apt install -y certbot python3-certbot-nginx

   # Générer certificat
   sudo certbot --nginx -d your-domain.com
   ```

5. **Backup automatique** :
   ```bash
   # Cron pour backup quotidien
   crontab -e

   # Ajouter:
   0 3 * * * /home/ubuntu/email-agent/scripts/backup-oracle.sh
   ```

### Monitoring sécurité

```bash
# Logs erreurs PostgreSQL
docker compose -f docker-compose.oracle-arm.yml logs db | grep ERROR

# Tentatives connexion API
docker compose -f docker-compose.oracle-arm.yml logs api | grep 401

# Utilisation ressources inhabituelle
docker stats --no-stream
```

---

## 🐛 Dépannage

### Service ne démarre pas

```bash
# Vérifier erreur spécifique
docker compose -f docker-compose.oracle-arm.yml logs <service>

# Vérifier ressources
free -h
df -h

# Rebuild service
docker compose -f docker-compose.oracle-arm.yml build <service>
docker compose -f docker-compose.oracle-arm.yml up -d <service>
```

### Performance lente

```bash
# Vérifier CPU/RAM
docker stats

# Vérifier PostgreSQL
docker compose -f docker-compose.oracle-arm.yml exec db psql -U emailagent -d emailagent -c "SELECT * FROM pg_stat_activity;"

# Vérifier Redis
docker compose -f docker-compose.oracle-arm.yml exec redis redis-cli info stats

# Vérifier Ollama
docker compose -f docker-compose.oracle-arm.yml logs ollama
```

### Ollama timeout

```bash
# Augmenter timeout dans .env
OLLAMA_TIMEOUT=180

# Redémarrer workers
docker compose -f docker-compose.oracle-arm.yml restart worker-1 worker-2 worker-3 worker-4
```

### Manque d'espace disque

```bash
# Nettoyer Docker
docker system prune -a --volumes

# Nettoyer logs
sudo truncate -s 0 logs/*.log

# Archiver vieux emails (TODO: implémenter)
```

---

## 📈 Optimisation performance

### Pour 20K+ emails

**Recommandations :**

1. **Sync progressive** (dans .env):
   ```bash
   ENABLE_PROGRESSIVE_SYNC=true
   INITIAL_SYNC_DAYS=30
   ```

2. **Classification hybride** :
   ```bash
   CLASSIFICATION_STRATEGY=hybrid
   RULES_FIRST=true
   AI_ONLY_FOR_UNCERTAIN=true
   ```

3. **Augmenter workers** si CPU disponible :
   ```bash
   # Modifier docker-compose.oracle-arm.yml
   # Ajouter worker-5, worker-6, etc.
   ```

4. **Tuning PostgreSQL** :
   - Voir `config/postgresql-arm.conf`
   - Ajuster selon utilisation réelle

### Monitoring performance

```bash
# Temps moyen classification
docker compose -f docker-compose.oracle-arm.yml exec db psql -U emailagent -d emailagent -c "SELECT AVG(processing_time_ms) FROM emails WHERE status='classified';"

# Emails traités par heure
docker compose -f docker-compose.oracle-arm.yml exec db psql -U emailagent -d emailagent -c "SELECT DATE_TRUNC('hour', processed_at) as hour, COUNT(*) FROM emails WHERE processed_at > NOW() - INTERVAL '24 hours' GROUP BY hour ORDER BY hour;"
```

---

## 🔗 Ressources

**Documentation :**
- [Guide rapide](../GUIDE_RAPIDE.md)
- [Ajouter compte email](ADD_EMAIL_ACCOUNT.md)
- [Exemple Gmail](../GMAIL_EXAMPLE.md)

**Oracle Cloud :**
- [Documentation OCI](https://docs.oracle.com/en-us/iaas/Content/home.htm)
- [Always Free Tier](https://www.oracle.com/cloud/free/)
- [Ampere A1 Instances](https://www.oracle.com/cloud/compute/arm/)

**Support :**
- GitHub Issues
- Logs: `docker compose logs`

---

**Version** : 1.0.0
**Testé avec** : Oracle Cloud ARM Ampere A1, Ubuntu 22.04 ARM64, Docker 24.0+
**Dernière mise à jour** : 2025-01-21
