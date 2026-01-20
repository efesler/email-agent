#!/bin/bash

# =============================================================================
# Email Agent - Script d'initialisation Ollama
# =============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

MODEL="${1:-mistral}"  # Default: mistral

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}  Ollama Setup${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""

# Vérifier que le container Ollama tourne
if ! docker-compose ps ollama | grep -q "Up"; then
    echo -e "${RED}Erreur: Le container Ollama n'est pas démarré${NC}"
    echo "Démarrez-le avec: docker-compose up -d ollama"
    exit 1
fi

echo -e "${YELLOW}Attente du démarrage d'Ollama...${NC}"
sleep 5

# Vérifier la connexion
echo -e "${YELLOW}Test de connexion à Ollama...${NC}"
if docker-compose exec ollama curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Ollama est accessible${NC}"
else
    echo -e "${RED}✗ Impossible de se connecter à Ollama${NC}"
    exit 1
fi

# Lister les modèles existants
echo ""
echo -e "${YELLOW}Modèles déjà installés:${NC}"
docker-compose exec ollama ollama list || echo "Aucun modèle installé"

# Demander confirmation
echo ""
echo -e "${YELLOW}Modèle à télécharger: ${MODEL}${NC}"
echo -e "${YELLOW}Tailles approximatives:${NC}"
echo "  - mistral: ~4.1 GB (recommandé)"
echo "  - phi3:mini: ~2.3 GB (plus léger, moins précis)"
echo "  - llama2: ~3.8 GB"
echo ""

# Vérifier si le modèle est déjà installé
if docker-compose exec ollama ollama list | grep -q "$MODEL"; then
    echo -e "${GREEN}Le modèle $MODEL est déjà installé${NC}"
    read -p "Voulez-vous le re-télécharger ? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Téléchargement annulé"
        exit 0
    fi
fi

# Télécharger le modèle
echo ""
echo -e "${YELLOW}Téléchargement du modèle $MODEL...${NC}"
echo -e "${YELLOW}Cela peut prendre 5-15 minutes selon votre connexion${NC}"
echo ""

docker-compose exec ollama ollama pull "$MODEL"

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ Modèle $MODEL téléchargé avec succès${NC}"
    echo ""
    
    # Tester le modèle
    echo -e "${YELLOW}Test du modèle...${NC}"
    docker-compose exec ollama ollama run "$MODEL" "Hello, respond with just 'OK'" --verbose=false | head -1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Le modèle fonctionne correctement${NC}"
    else
        echo -e "${RED}✗ Erreur lors du test du modèle${NC}"
    fi
else
    echo -e "${RED}✗ Erreur lors du téléchargement${NC}"
    exit 1
fi

# Mettre à jour .env si nécessaire
echo ""
echo -e "${YELLOW}Mise à jour de la configuration...${NC}"
if [ -f .env ]; then
    if grep -q "OLLAMA_MODEL=" .env; then
        sed -i "s/OLLAMA_MODEL=.*/OLLAMA_MODEL=$MODEL/" .env
        echo -e "${GREEN}✓ .env mis à jour avec OLLAMA_MODEL=$MODEL${NC}"
    else
        echo "OLLAMA_MODEL=$MODEL" >> .env
        echo -e "${GREEN}✓ OLLAMA_MODEL=$MODEL ajouté à .env${NC}"
    fi
fi

echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}  Configuration terminée !${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo "Modèles installés:"
docker-compose exec ollama ollama list
echo ""
echo "Pour tester la classification:"
echo "  curl -X POST http://localhost:8000/api/classification/test \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"subject\": \"Test\", \"sender\": \"test@example.com\", \"body_preview\": \"Test email\"}'"
echo ""
