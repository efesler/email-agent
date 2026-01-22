#!/bin/bash

# ===================================
# Script de déploiement Oracle ARM Free Tier
# Email Agent AI
# ===================================

set -e  # Exit on error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
log_info() {
    echo -e "${BLUE}ℹ ${NC}$1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# Banner
echo "═══════════════════════════════════════════════════"
echo "  Email Agent AI - Oracle ARM Deployment"
echo "  Platform: ARM64 (Ampere A1)"
echo "  Resources: 24 GB RAM, 4 OCPUs"
echo "═══════════════════════════════════════════════════"
echo ""

# ===================================
# 1. Vérifications préalables
# ===================================

log_info "Étape 1/8: Vérifications système..."

# Vérifier architecture
ARCH=$(uname -m)
if [ "$ARCH" != "aarch64" ] && [ "$ARCH" != "arm64" ]; then
    log_error "Architecture non supportée: $ARCH (ARM64 requis)"
    exit 1
fi
log_success "Architecture ARM64 détectée"

# Vérifier Docker
if ! command -v docker &> /dev/null; then
    log_error "Docker n'est pas installé"
    exit 1
fi
log_success "Docker installé: $(docker --version)"

# Vérifier Docker Compose
if ! command -v docker compose &> /dev/null; then
    log_error "Docker Compose n'est pas installé"
    exit 1
fi
log_success "Docker Compose installé"

# Vérifier RAM
TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
if [ "$TOTAL_RAM" -lt 20 ]; then
    log_warning "RAM détectée: ${TOTAL_RAM}GB (24GB recommandés)"
else
    log_success "RAM détectée: ${TOTAL_RAM}GB"
fi

# Vérifier espace disque
AVAILABLE_DISK=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$AVAILABLE_DISK" -lt 50 ]; then
    log_warning "Espace disque: ${AVAILABLE_DISK}GB (50GB+ recommandés)"
else
    log_success "Espace disque: ${AVAILABLE_DISK}GB"
fi

echo ""

# ===================================
# 2. Configuration environnement
# ===================================

log_info "Étape 2/8: Configuration environnement..."

# Vérifier si .env existe
if [ ! -f .env ]; then
    if [ -f .env.oracle-arm ]; then
        log_warning ".env non trouvé, copie depuis .env.oracle-arm"
        cp .env.oracle-arm .env
        log_success ".env créé depuis template"
        log_warning "IMPORTANT: Éditez .env et changez tous les 'CHANGEME'"
        read -p "Voulez-vous éditer .env maintenant? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            ${EDITOR:-nano} .env
        fi
    else
        log_error ".env et .env.oracle-arm non trouvés"
        exit 1
    fi
else
    log_success ".env trouvé"
fi

# Vérifier les CHANGEME dans .env
if grep -q "CHANGEME" .env; then
    log_error ".env contient encore des 'CHANGEME' - configurez-le d'abord!"
    log_info "Utilisez: nano .env"
    exit 1
fi

log_success "Configuration .env validée"

echo ""

# ===================================
# 3. Création des répertoires
# ===================================

log_info "Étape 3/8: Création des répertoires..."

mkdir -p logs data config
mkdir -p data/uploads data/attachments
chmod 755 logs data config
log_success "Répertoires créés"

echo ""

# ===================================
# 4. Build des images Docker ARM
# ===================================

log_info "Étape 4/8: Build des images Docker ARM (peut prendre 10-20 min)..."

docker compose -f docker-compose.oracle-arm.yml build --no-cache

log_success "Images Docker ARM buildées"

echo ""

# ===================================
# 5. Démarrage des services
# ===================================

log_info "Étape 5/8: Démarrage des services..."

docker compose -f docker-compose.oracle-arm.yml up -d

log_success "Services démarrés"

echo ""

# ===================================
# 6. Attente initialisation
# ===================================

log_info "Étape 6/8: Attente initialisation des services..."

# Attendre PostgreSQL
log_info "Attente PostgreSQL..."
for i in {1..30}; do
    if docker compose -f docker-compose.oracle-arm.yml exec -T db pg_isready -U emailagent > /dev/null 2>&1; then
        log_success "PostgreSQL prêt"
        break
    fi
    sleep 2
    echo -n "."
done
echo ""

# Attendre Redis
log_info "Attente Redis..."
for i in {1..20}; do
    if docker compose -f docker-compose.oracle-arm.yml exec -T redis redis-cli ping > /dev/null 2>&1; then
        log_success "Redis prêt"
        break
    fi
    sleep 2
    echo -n "."
done
echo ""

# Attendre API
log_info "Attente API..."
for i in {1..30}; do
    if curl -sf http://localhost:8000/health > /dev/null 2>&1; then
        log_success "API prête"
        break
    fi
    sleep 2
    echo -n "."
done
echo ""

echo ""

# ===================================
# 7. Téléchargement Ollama Mistral
# ===================================

log_info "Étape 7/8: Téléchargement modèle Ollama Mistral (ARM64)..."
log_warning "Cela peut prendre 5-10 minutes selon votre connexion"

docker compose -f docker-compose.oracle-arm.yml exec ollama ollama pull mistral

log_success "Modèle Mistral téléchargé"

echo ""

# ===================================
# 8. Vérification finale
# ===================================

log_info "Étape 8/8: Vérification finale..."

# Vérifier tous les services
ALL_HEALTHY=true

services=("db" "redis" "api" "worker-1" "worker-2" "worker-3" "worker-4" "scheduler" "ollama")

for service in "${services[@]}"; do
    if docker ps --filter "name=email-agent-$service" --filter "status=running" | grep -q "$service"; then
        log_success "$service: Running"
    else
        log_error "$service: NOT Running"
        ALL_HEALTHY=false
    fi
done

echo ""

# ===================================
# Résumé final
# ===================================

if [ "$ALL_HEALTHY" = true ]; then
    echo "═══════════════════════════════════════════════════"
    log_success "Déploiement réussi! 🎉"
    echo "═══════════════════════════════════════════════════"
    echo ""
    echo "📋 Services accessibles:"
    echo "   • API:        http://$(hostname -I | awk '{print $1}'):8000"
    echo "   • API Docs:   http://$(hostname -I | awk '{print $1}'):8000/docs"
    echo "   • Health:     http://$(hostname -I | awk '{print $1}'):8000/health"
    echo "   • Portainer:  http://$(hostname -I | awk '{print $1}'):9000"
    echo ""
    echo "📊 Monitoring:"
    echo "   docker compose -f docker-compose.oracle-arm.yml ps"
    echo "   docker compose -f docker-compose.oracle-arm.yml logs -f"
    echo ""
    echo "📧 Ajouter un compte email:"
    echo "   docker compose -f docker-compose.oracle-arm.yml exec api python scripts/add_email_account.py"
    echo ""
    echo "🔍 Vérifier les workers:"
    echo "   docker compose -f docker-compose.oracle-arm.yml exec worker-1 celery -A worker.celery_app inspect active"
    echo ""
    echo "📈 Stats système:"
    echo "   docker stats"
    echo ""
else
    echo "═══════════════════════════════════════════════════"
    log_error "Déploiement avec erreurs"
    echo "═══════════════════════════════════════════════════"
    echo ""
    log_info "Vérifiez les logs:"
    echo "   docker compose -f docker-compose.oracle-arm.yml logs"
fi

echo ""
echo "Documentation complète: docs/DEPLOY_ORACLE_ARM.md"
echo ""
