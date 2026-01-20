#!/bin/bash

# =============================================================================
# Email Agent - Script de backup
# =============================================================================

set -e

# Configuration
BACKUP_DIR="${BACKUP_DIR:-/var/backups/email-agent}"
PROJECT_DIR="${PROJECT_DIR:-/opt/email-agent}"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="email-agent-backup-$DATE"

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}  Email Agent - Backup${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""

# Créer le répertoire de backup s'il n'existe pas
mkdir -p "$BACKUP_DIR"

# Créer un répertoire temporaire pour ce backup
TEMP_BACKUP_DIR="$BACKUP_DIR/tmp-$DATE"
mkdir -p "$TEMP_BACKUP_DIR"

# 1. Backup de la base de données
echo -e "${YELLOW}[1/4] Backup de la base de données PostgreSQL...${NC}"
docker exec email-agent-db pg_dump -U emailagent emailagent > "$TEMP_BACKUP_DIR/database.sql"
gzip "$TEMP_BACKUP_DIR/database.sql"
echo -e "${GREEN}✓ Database backup créé${NC}"

# 2. Backup des données
echo -e "${YELLOW}[2/4] Backup des données et configuration...${NC}"
if [ -d "$PROJECT_DIR/data" ]; then
    cp -r "$PROJECT_DIR/data" "$TEMP_BACKUP_DIR/"
fi
if [ -f "$PROJECT_DIR/.env" ]; then
    cp "$PROJECT_DIR/.env" "$TEMP_BACKUP_DIR/"
fi
echo -e "${GREEN}✓ Données sauvegardées${NC}"

# 3. Backup des logs (derniers 7 jours)
echo -e "${YELLOW}[3/4] Backup des logs récents...${NC}"
if [ -d "$PROJECT_DIR/logs" ]; then
    mkdir -p "$TEMP_BACKUP_DIR/logs"
    find "$PROJECT_DIR/logs" -name "*.log" -mtime -7 -exec cp {} "$TEMP_BACKUP_DIR/logs/" \;
fi
echo -e "${GREEN}✓ Logs sauvegardés${NC}"

# 4. Créer l'archive finale
echo -e "${YELLOW}[4/4] Création de l'archive...${NC}"
cd "$BACKUP_DIR"
tar -czf "$BACKUP_NAME.tar.gz" -C "$TEMP_BACKUP_DIR" .

# Nettoyer le répertoire temporaire
rm -rf "$TEMP_BACKUP_DIR"

# Calculer la taille
BACKUP_SIZE=$(du -h "$BACKUP_NAME.tar.gz" | cut -f1)

echo -e "${GREEN}✓ Archive créée${NC}"
echo ""
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}  Backup terminé !${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo "Archive: $BACKUP_DIR/$BACKUP_NAME.tar.gz"
echo "Taille: $BACKUP_SIZE"
echo ""

# Nettoyer les anciens backups (garder les 30 derniers jours)
echo -e "${YELLOW}Nettoyage des anciens backups...${NC}"
find "$BACKUP_DIR" -name "email-agent-backup-*.tar.gz" -mtime +30 -delete
echo -e "${GREEN}✓ Anciens backups nettoyés${NC}"
echo ""

# Liste des backups disponibles
echo "Backups disponibles:"
ls -lh "$BACKUP_DIR"/*.tar.gz 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}' || echo "  Aucun backup trouvé"
echo ""
