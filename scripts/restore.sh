#!/bin/bash

# =============================================================================
# Email Agent - Script de restauration
# =============================================================================

set -e

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Vérifier les arguments
if [ $# -eq 0 ]; then
    echo -e "${RED}Erreur: Vous devez spécifier le fichier de backup${NC}"
    echo "Usage: $0 <backup-file.tar.gz>"
    echo ""
    echo "Backups disponibles:"
    ls -lh /var/backups/email-agent/*.tar.gz 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}' || echo "  Aucun backup trouvé"
    exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
    echo -e "${RED}Erreur: Fichier de backup introuvable: $BACKUP_FILE${NC}"
    exit 1
fi

# Configuration
PROJECT_DIR="${PROJECT_DIR:-/opt/email-agent}"
TEMP_RESTORE_DIR="/tmp/email-agent-restore-$$"

echo -e "${YELLOW}=====================================${NC}"
echo -e "${YELLOW}  Email Agent - Restauration${NC}"
echo -e "${YELLOW}=====================================${NC}"
echo ""
echo -e "${RED}ATTENTION: Cette opération va écraser les données existantes!${NC}"
echo ""
read -p "Êtes-vous sûr de vouloir continuer? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Restauration annulée."
    exit 0
fi

echo ""

# Créer le répertoire temporaire
mkdir -p "$TEMP_RESTORE_DIR"

# 1. Extraire l'archive
echo -e "${YELLOW}[1/4] Extraction de l'archive...${NC}"
tar -xzf "$BACKUP_FILE" -C "$TEMP_RESTORE_DIR"
echo -e "${GREEN}✓ Archive extraite${NC}"

# 2. Arrêter les services
echo -e "${YELLOW}[2/4] Arrêt des services...${NC}"
cd "$PROJECT_DIR"
docker-compose stop api worker scheduler
echo -e "${GREEN}✓ Services arrêtés${NC}"

# 3. Restaurer la base de données
echo -e "${YELLOW}[3/4] Restauration de la base de données...${NC}"
if [ -f "$TEMP_RESTORE_DIR/database.sql.gz" ]; then
    # Décompresser le dump SQL
    gunzip -c "$TEMP_RESTORE_DIR/database.sql.gz" > "$TEMP_RESTORE_DIR/database.sql"
    
    # Restaurer dans PostgreSQL
    docker exec -i email-agent-db psql -U emailagent emailagent < "$TEMP_RESTORE_DIR/database.sql"
    
    echo -e "${GREEN}✓ Base de données restaurée${NC}"
else
    echo -e "${RED}✗ Aucun fichier de base de données trouvé dans le backup${NC}"
fi

# 4. Restaurer les données et configuration
echo -e "${YELLOW}[4/4] Restauration des données...${NC}"

# Restaurer .env
if [ -f "$TEMP_RESTORE_DIR/.env" ]; then
    cp "$TEMP_RESTORE_DIR/.env" "$PROJECT_DIR/.env"
    echo -e "${GREEN}✓ Configuration restaurée${NC}"
fi

# Restaurer le répertoire data
if [ -d "$TEMP_RESTORE_DIR/data" ]; then
    rm -rf "$PROJECT_DIR/data"
    cp -r "$TEMP_RESTORE_DIR/data" "$PROJECT_DIR/"
    echo -e "${GREEN}✓ Données restaurées${NC}"
fi

# Nettoyer
rm -rf "$TEMP_RESTORE_DIR"

# Redémarrer les services
echo ""
echo -e "${YELLOW}Redémarrage des services...${NC}"
docker-compose start api worker scheduler
docker-compose ps

echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}  Restauration terminée !${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo "Les services redémarrent. Vérifiez les logs avec:"
echo "  docker-compose logs -f"
echo ""
