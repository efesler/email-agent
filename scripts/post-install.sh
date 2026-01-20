#!/bin/bash

# =============================================================================
# Email Agent - Post Installation Script
# Appelé automatiquement après le premier docker-compose up
# =============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}  Post-Installation Setup${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""

# Attendre que tous les services soient prêts
echo -e "${YELLOW}Attente du démarrage des services...${NC}"
sleep 10

# Vérifier PostgreSQL
echo -e "${YELLOW}Vérification de PostgreSQL...${NC}"
for i in {1..30}; do
    if docker-compose exec -T db pg_isready -U emailagent > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PostgreSQL prêt${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}✗ PostgreSQL timeout${NC}"
        exit 1
    fi
    sleep 1
done

# Vérifier Redis
echo -e "${YELLOW}Vérification de Redis...${NC}"
if docker-compose exec -T redis redis-cli ping > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Redis prêt${NC}"
else
    echo -e "${RED}✗ Redis non accessible${NC}"
fi

# Vérifier l'API
echo -e "${YELLOW}Vérification de l'API...${NC}"
for i in {1..30}; do
    if curl -s http://localhost:8000/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓ API prête${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${YELLOW}⚠ API timeout (peut prendre plus de temps au premier démarrage)${NC}"
    fi
    sleep 1
done

# Proposer de télécharger Ollama
echo ""
echo -e "${YELLOW}Le modèle Ollama n'est pas encore téléchargé${NC}"
echo "Voulez-vous télécharger le modèle maintenant ?"
echo "(Recommandé - environ 4 GB - prend 5-15 minutes)"
echo ""
read -p "Télécharger maintenant ? (Y/n): " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    chmod +x ./scripts/setup-ollama.sh
    ./scripts/setup-ollama.sh mistral
fi

echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}  Installation complète !${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo "Prochaines étapes:"
echo ""
echo "1. Accéder à l'interface:"
echo "   → API: http://$(curl -s ifconfig.me 2>/dev/null || echo 'localhost'):8000"
echo "   → Portainer: http://$(curl -s ifconfig.me 2>/dev/null || echo 'localhost'):9000"
echo ""
echo "2. Voir les logs:"
echo "   docker-compose logs -f"
echo ""
echo "3. Ajouter un compte email (à venir)"
echo ""
echo "Pour plus d'informations, consultez:"
echo "  - README.md"
echo "  - QUICKSTART.md"
echo ""
