#!/bin/bash

# =============================================================================
# Email Agent - Pre-deployment Check
# Vérifie que tout est prêt avant le déploiement
# =============================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}  Pre-Deployment Checklist${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""

# Fonction pour checker
check() {
    local name=$1
    local command=$2
    local is_critical=${3:-true}
    
    echo -ne "Checking $name... "
    
    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        if [ "$is_critical" = true ]; then
            echo -e "${RED}✗ ERREUR${NC}"
            ((ERRORS++))
        else
            echo -e "${YELLOW}⚠ WARNING${NC}"
            ((WARNINGS++))
        fi
        return 1
    fi
}

# Docker
echo -e "${YELLOW}[1/8] Docker${NC}"
check "Docker installed" "command -v docker"
check "Docker running" "docker ps"
check "Docker Compose installed" "command -v docker-compose"
echo ""

# Fichiers requis
echo -e "${YELLOW}[2/8] Required Files${NC}"
check ".env exists" "test -f .env"
check "docker-compose.yml" "test -f docker-compose.yml"
check "requirements.txt" "test -f requirements.txt"
echo ""

# Configuration
echo -e "${YELLOW}[3/8] Configuration${NC}"
if [ -f .env ]; then
    check "SECRET_KEY set" "grep -q 'SECRET_KEY=' .env && ! grep -q 'SECRET_KEY=changeme' .env"
    check "ENCRYPTION_KEY set" "grep -q 'ENCRYPTION_KEY=' .env && ! grep -q 'ENCRYPTION_KEY=changeme' .env"
    check "DB_PASSWORD set" "grep -q 'DB_PASSWORD=' .env"
    check "ADMIN_PASSWORD changed" "! grep -q 'ADMIN_PASSWORD=changeme' .env" false
else
    echo -e "${RED}✗ .env file missing${NC}"
    ((ERRORS++))
fi
echo ""

# Ports disponibles
echo -e "${YELLOW}[4/8] Ports${NC}"
check "Port 80 available" "! sudo lsof -i :80 > /dev/null 2>&1"
check "Port 443 available" "! sudo lsof -i :443 > /dev/null 2>&1" false
check "Port 8000 available" "! lsof -i :8000 > /dev/null 2>&1"
check "Port 9000 available" "! lsof -i :9000 > /dev/null 2>&1" false
echo ""

# Espace disque
echo -e "${YELLOW}[5/8] Disk Space${NC}"
AVAILABLE=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
echo "Available disk space: ${AVAILABLE}GB"
if [ "$AVAILABLE" -lt 20 ]; then
    echo -e "${RED}✗ Less than 20GB available${NC}"
    ((ERRORS++))
elif [ "$AVAILABLE" -lt 50 ]; then
    echo -e "${YELLOW}⚠ Less than 50GB available (recommended)${NC}"
    ((WARNINGS++))
else
    echo -e "${GREEN}✓ Sufficient disk space${NC}"
fi
echo ""

# RAM
echo -e "${YELLOW}[6/8] Memory${NC}"
TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
echo "Total RAM: ${TOTAL_RAM}GB"
if [ "$TOTAL_RAM" -lt 8 ]; then
    echo -e "${RED}✗ Less than 8GB RAM (minimum required)${NC}"
    ((ERRORS++))
elif [ "$TOTAL_RAM" -lt 16 ]; then
    echo -e "${YELLOW}⚠ Less than 16GB RAM (recommended for Ollama)${NC}"
    ((WARNINGS++))
else
    echo -e "${GREEN}✓ Sufficient RAM${NC}"
fi
echo ""

# Firewall
echo -e "${YELLOW}[7/8] Firewall${NC}"
if command -v ufw > /dev/null 2>&1; then
    if sudo ufw status | grep -q "Status: active"; then
        check "UFW allows port 80" "sudo ufw status | grep -q '80/tcp.*ALLOW'"
        check "UFW allows port 443" "sudo ufw status | grep -q '443/tcp.*ALLOW'" false
    else
        echo -e "${YELLOW}⚠ UFW not active${NC}"
        ((WARNINGS++))
    fi
else
    echo -e "${YELLOW}⚠ UFW not installed${NC}"
    ((WARNINGS++))
fi
echo ""

# Permissions
echo -e "${YELLOW}[8/8] Permissions${NC}"
check "Can execute scripts" "test -x scripts/setup-oracle.sh"
check "Can write to logs/" "test -w logs/ || mkdir -p logs/"
check "Can write to data/" "test -w data/ || mkdir -p data/"
echo ""

# Résumé
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}  Summary${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""

if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}✗ $ERRORS critical error(s) found${NC}"
    echo -e "${RED}Please fix errors before deployment${NC}"
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}⚠ $WARNINGS warning(s) found${NC}"
    echo -e "${YELLOW}Review warnings, but deployment can proceed${NC}"
    echo ""
    read -p "Continue with deployment? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Deployment cancelled"
        exit 0
    fi
else
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo -e "${GREEN}Ready for deployment${NC}"
fi

echo ""
echo "Next steps:"
echo "  1. docker-compose up -d"
echo "  2. ./scripts/setup-ollama.sh"
echo "  3. Check logs: docker-compose logs -f"
echo ""
