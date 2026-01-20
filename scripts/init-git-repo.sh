#!/bin/bash

# =============================================================================
# Email Agent - Git Repository Setup Script
# Usage: ./scripts/init-git-repo.sh <github-username>
# =============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

if [ $# -eq 0 ]; then
    echo -e "${RED}Erreur: Vous devez fournir votre nom d'utilisateur GitHub${NC}"
    echo "Usage: $0 <github-username>"
    exit 1
fi

GITHUB_USER=$1
REPO_NAME="email-agent"

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}  Git Repository Setup${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""

# Vérifier que git est installé
if ! command -v git &> /dev/null; then
    echo -e "${RED}Git n'est pas installé. Installez-le avec:${NC}"
    echo "  sudo apt install git"
    exit 1
fi

# Vérifier si on est dans le bon répertoire
if [ ! -f "README.md" ] || [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}Erreur: Ce script doit être exécuté depuis le répertoire email-agent${NC}"
    exit 1
fi

# Demander confirmation
echo -e "${YELLOW}Ce script va:${NC}"
echo "  1. Initialiser un repo Git local"
echo "  2. Configurer .gitignore"
echo "  3. Faire le commit initial"
echo "  4. Configurer le remote vers GitHub"
echo "  5. Pousser le code"
echo ""
echo "Remote URL: https://github.com/${GITHUB_USER}/${REPO_NAME}.git"
echo ""
read -p "Continuer ? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Annulé."
    exit 0
fi

# Configurer Git
echo -e "${YELLOW}[1/6] Configuration Git...${NC}"
git config --global init.defaultBranch main 2>/dev/null || true

if [ -z "$(git config user.name)" ]; then
    echo -n "Votre nom pour Git: "
    read GIT_NAME
    git config --global user.name "$GIT_NAME"
fi

if [ -z "$(git config user.email)" ]; then
    echo -n "Votre email pour Git: "
    read GIT_EMAIL
    git config --global user.email "$GIT_EMAIL"
fi

echo -e "${GREEN}✓ Configuration Git OK${NC}"

# Initialiser le repo
echo -e "${YELLOW}[2/6] Initialisation du repo Git...${NC}"

if [ -d ".git" ]; then
    echo -e "${YELLOW}⚠ .git existe déjà, réinitialisation...${NC}"
    rm -rf .git
fi

git init
echo -e "${GREEN}✓ Repo initialisé${NC}"

# Créer .gitignore si nécessaire (normalement déjà présent)
echo -e "${YELLOW}[3/6] Vérification .gitignore...${NC}"
if [ -f ".gitignore" ]; then
    echo -e "${GREEN}✓ .gitignore présent${NC}"
else
    echo -e "${RED}✗ .gitignore manquant${NC}"
    exit 1
fi

# Add et commit
echo -e "${YELLOW}[4/6] Commit initial...${NC}"
git add .
git commit -m "feat: Initial commit - Email Agent AI

- Complete Docker infrastructure (PostgreSQL, Redis, Ollama, Nginx)
- FastAPI backend with authentication and email management
- Celery workers for async processing
- Ollama-based AI classification
- Oracle Cloud deployment scripts
- Comprehensive documentation
- CI/CD with GitHub Actions

Production-ready v1.0.0"

echo -e "${GREEN}✓ Commit créé${NC}"

# Configurer le remote
echo -e "${YELLOW}[5/6] Configuration du remote GitHub...${NC}"
git remote add origin "https://github.com/${GITHUB_USER}/${REPO_NAME}.git"
echo -e "${GREEN}✓ Remote configuré${NC}"

# Pousser
echo ""
echo -e "${YELLOW}[6/6] Push vers GitHub...${NC}"
echo ""
echo -e "${RED}IMPORTANT:${NC}"
echo "  1. Assurez-vous d'avoir créé le repo sur GitHub:"
echo "     https://github.com/new"
echo "  2. Nom du repo: ${REPO_NAME}"
echo "  3. Laissez-le vide (pas de README, pas de .gitignore)"
echo ""
read -p "Le repo GitHub est créé et vide ? (y/N): " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${YELLOW}Pas de problème !${NC}"
    echo ""
    echo "Quand vous serez prêt, exécutez:"
    echo "  git push -u origin main"
    echo ""
    exit 0
fi

echo ""
echo -e "${YELLOW}Push en cours...${NC}"

if git push -u origin main; then
    echo ""
    echo -e "${GREEN}=====================================${NC}"
    echo -e "${GREEN}  ✓ Repo GitHub configuré !${NC}"
    echo -e "${GREEN}=====================================${NC}"
    echo ""
    echo "Votre repo est disponible à:"
    echo "  https://github.com/${GITHUB_USER}/${REPO_NAME}"
    echo ""
    echo "Prochaines étapes:"
    echo "  1. Configurer les GitHub Actions (si besoin)"
    echo "  2. Ajouter une description au repo"
    echo "  3. Ajouter des topics: email, ai, llm, automation, oracle-cloud"
    echo "  4. Partager avec la communauté !"
    echo ""
else
    echo ""
    echo -e "${RED}Erreur lors du push${NC}"
    echo ""
    echo "Vérifiez:"
    echo "  - Le repo existe sur GitHub"
    echo "  - Vous avez les droits d'accès"
    echo "  - Votre authentification GitHub est configurée"
    echo ""
    echo "Pour pousser manuellement:"
    echo "  git push -u origin main"
    echo ""
    exit 1
fi
