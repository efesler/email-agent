#!/bin/bash

# =============================================================================
# Email Agent - Installation Script pour Oracle Cloud Free Tier
# =============================================================================

set -e  # Exit on error

# Couleurs pour output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}"
echo "=========================================="
echo "  Email Agent AI - Installation Oracle"
echo "=========================================="
echo -e "${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Ce script doit être exécuté en tant que root (sudo)${NC}" 
   exit 1
fi

# Variables
INSTALL_DIR="/opt/email-agent"
USER="ubuntu"

# -----------------
# 1. Mise à jour système
# -----------------
echo -e "${YELLOW}[1/8] Mise à jour du système...${NC}"
apt update && apt upgrade -y

# -----------------
# 2. Installation dépendances
# -----------------
echo -e "${YELLOW}[2/8] Installation des dépendances...${NC}"
apt install -y \
    git \
    curl \
    wget \
    vim \
    htop \
    ufw \
    fail2ban \
    ca-certificates \
    gnupg \
    lsb-release

# -----------------
# 3. Installation Docker
# -----------------
echo -e "${YELLOW}[3/8] Installation de Docker...${NC}"

# Supprimer anciennes versions
apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Add Docker's official GPG key
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Démarrer et activer Docker
systemctl start docker
systemctl enable docker

# Ajouter l'utilisateur ubuntu au groupe docker
usermod -aG docker $USER

echo -e "${GREEN}✓ Docker installé${NC}"

# -----------------
# 4. Installation Docker Compose standalone
# -----------------
echo -e "${YELLOW}[4/8] Installation de Docker Compose...${NC}"

DOCKER_COMPOSE_VERSION="v2.24.5"
curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

echo -e "${GREEN}✓ Docker Compose installé${NC}"

# -----------------
# 5. Configuration Firewall
# -----------------
echo -e "${YELLOW}[5/8] Configuration du firewall...${NC}"

# Activer UFW
ufw --force enable

# Règles de base
ufw default deny incoming
ufw default allow outgoing

# Autoriser SSH (port 22)
ufw allow 22/tcp

# Autoriser HTTP et HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# Autoriser Portainer (optionnel, peut être retiré après configuration)
ufw allow 9000/tcp

# Recharger UFW
ufw reload

echo -e "${GREEN}✓ Firewall configuré${NC}"

# -----------------
# 6. Configuration Fail2Ban
# -----------------
echo -e "${YELLOW}[6/8] Configuration de Fail2Ban...${NC}"

systemctl enable fail2ban
systemctl start fail2ban

cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = 22
logpath = /var/log/auth.log
EOF

systemctl restart fail2ban

echo -e "${GREEN}✓ Fail2Ban configuré${NC}"

# -----------------
# 7. Copie du projet
# -----------------
echo -e "${YELLOW}[7/8] Configuration du projet...${NC}"

# Si le script est exécuté depuis le repo cloné
if [ -d "$(pwd)/api" ]; then
    PROJECT_DIR=$(pwd)
    echo "Projet détecté dans : $PROJECT_DIR"
else
    echo -e "${RED}Erreur: Exécutez ce script depuis le répertoire du projet${NC}"
    exit 1
fi

# Créer le fichier .env s'il n'existe pas
if [ ! -f "$PROJECT_DIR/.env" ]; then
    echo -e "${YELLOW}Création du fichier .env...${NC}"
    cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
    
    # Générer des clés aléatoires
    SECRET_KEY=$(openssl rand -hex 32)
    ENCRYPTION_KEY=$(openssl rand -hex 32)
    DB_PASSWORD=$(openssl rand -hex 16)
    REDIS_PASSWORD=$(openssl rand -hex 16)
    
    # Remplacer dans .env
    sed -i "s/SECRET_KEY=.*/SECRET_KEY=$SECRET_KEY/" "$PROJECT_DIR/.env"
    sed -i "s/ENCRYPTION_KEY=.*/ENCRYPTION_KEY=$ENCRYPTION_KEY/" "$PROJECT_DIR/.env"
    sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=$DB_PASSWORD/" "$PROJECT_DIR/.env"
    sed -i "s/REDIS_PASSWORD=.*/REDIS_PASSWORD=$REDIS_PASSWORD/" "$PROJECT_DIR/.env"
    
    echo -e "${GREEN}✓ Fichier .env créé avec clés sécurisées${NC}"
fi

# Créer les répertoires nécessaires
mkdir -p "$PROJECT_DIR"/{logs,data,backups}
chown -R $USER:$USER "$PROJECT_DIR"

# -----------------
# 8. Configuration backup automatique
# -----------------
echo -e "${YELLOW}[8/8] Configuration des backups automatiques...${NC}"

# Créer le répertoire de backup
mkdir -p /var/backups/email-agent

# Créer le script de backup quotidien
cat > /etc/cron.daily/email-agent-backup << 'EOFBACKUP'
#!/bin/bash
BACKUP_DIR="/var/backups/email-agent"
DATE=$(date +%Y%m%d_%H%M%S)
PROJECT_DIR="/opt/email-agent"

# Backup PostgreSQL
docker exec email-agent-db pg_dump -U emailagent emailagent | gzip > "$BACKUP_DIR/db-$DATE.sql.gz"

# Backup configuration et données
tar -czf "$BACKUP_DIR/data-$DATE.tar.gz" -C "$PROJECT_DIR" .env data/

# Nettoyer les backups de plus de 30 jours
find "$BACKUP_DIR" -name "*.gz" -mtime +30 -delete

echo "Backup completed: $DATE"
EOFBACKUP

chmod +x /etc/cron.daily/email-agent-backup

echo -e "${GREEN}✓ Backups automatiques configurés${NC}"

# -----------------
# Instructions finales
# -----------------
echo ""
echo -e "${GREEN}=========================================="
echo "  Installation terminée !"
echo -e "==========================================${NC}"
echo ""
echo "Prochaines étapes :"
echo ""
echo "1. Éditer la configuration :"
echo "   cd $(pwd)"
echo "   nano .env"
echo ""
echo "2. Démarrer les services :"
echo "   docker-compose up -d"
echo ""
echo "3. Télécharger le modèle LLM (requis) :"
echo "   docker-compose exec ollama ollama pull mistral"
echo "   (Cela va prendre quelques minutes)"
echo ""
echo "4. Vérifier le statut :"
echo "   docker-compose ps"
echo ""
echo "5. Accéder à l'interface :"
echo "   http://$(curl -s ifconfig.me)"
echo "   Portainer: http://$(curl -s ifconfig.me):9000"
echo ""
echo "6. Voir les logs :"
echo "   docker-compose logs -f"
echo ""
echo -e "${YELLOW}Important:${NC}"
echo "- Changez le mot de passe admin dans l'interface web"
echo "- Configurez SSL/HTTPS si vous avez un nom de domaine"
echo "- Les backups quotidiens sont dans /var/backups/email-agent/"
echo ""
echo -e "${GREEN}Pour plus d'informations, consultez le README.md${NC}"
echo ""
