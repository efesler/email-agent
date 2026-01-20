.PHONY: help setup up down restart logs build clean backup restore test lint

# Variables
DOCKER_COMPOSE = docker-compose
DOCKER_EXEC = docker-compose exec

help: ## Afficher l'aide
	@echo "Email Agent AI - Commandes disponibles:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

setup: ## Installation initiale (Oracle Cloud)
	@echo "Exécution du script d'installation..."
	sudo ./scripts/setup-oracle.sh

up: ## Démarrer tous les services
	$(DOCKER_COMPOSE) up -d
	@echo "Services démarrés. Vérification du statut..."
	$(DOCKER_COMPOSE) ps

down: ## Arrêter tous les services
	$(DOCKER_COMPOSE) down

restart: ## Redémarrer tous les services
	$(DOCKER_COMPOSE) restart

stop: ## Arrêter sans supprimer les containers
	$(DOCKER_COMPOSE) stop

start: ## Démarrer les containers existants
	$(DOCKER_COMPOSE) start

logs: ## Voir les logs (tous les services)
	$(DOCKER_COMPOSE) logs -f

logs-api: ## Voir les logs de l'API
	$(DOCKER_COMPOSE) logs -f api

logs-worker: ## Voir les logs du worker
	$(DOCKER_COMPOSE) logs -f worker

logs-ollama: ## Voir les logs d'Ollama
	$(DOCKER_COMPOSE) logs -f ollama

build: ## Rebuild les images Docker
	$(DOCKER_COMPOSE) build

clean: ## Nettoyer les containers et volumes
	$(DOCKER_COMPOSE) down -v
	@echo "Containers et volumes supprimés"

ps: ## Statut des services
	$(DOCKER_COMPOSE) ps

# Ollama
ollama-pull: ## Télécharger le modèle Ollama (mistral)
	$(DOCKER_EXEC) ollama ollama pull mistral

ollama-pull-phi: ## Télécharger le modèle Phi3 (plus léger)
	$(DOCKER_EXEC) ollama ollama pull phi3:mini

ollama-list: ## Lister les modèles Ollama
	$(DOCKER_EXEC) ollama ollama list

ollama-shell: ## Shell interactif dans le container Ollama
	$(DOCKER_EXEC) ollama bash

# Base de données
db-shell: ## Shell PostgreSQL
	$(DOCKER_EXEC) db psql -U emailagent emailagent

db-backup: ## Backup manuel de la base
	./scripts/backup.sh

db-restore: ## Restaurer un backup (spécifier BACKUP_FILE=)
	./scripts/restore.sh $(BACKUP_FILE)

# API
api-shell: ## Shell dans le container API
	$(DOCKER_EXEC) api bash

worker-shell: ## Shell dans le container worker
	$(DOCKER_EXEC) worker bash

# Tests
test: ## Exécuter les tests
	$(DOCKER_EXEC) api pytest tests/ -v

test-cov: ## Tests avec coverage
	$(DOCKER_EXEC) api pytest tests/ -v --cov=. --cov-report=html

# Développement
lint: ## Linter le code Python
	$(DOCKER_EXEC) api black api/ worker/ shared/
	$(DOCKER_EXEC) api flake8 api/ worker/ shared/

format: ## Formater le code
	$(DOCKER_EXEC) api black api/ worker/ shared/

# Stats et monitoring
stats: ## Voir les stats Docker
	docker stats

health: ## Vérifier la santé des services
	@echo "=== Health Check ==="
	@curl -s http://localhost:8000/health | python3 -m json.tool || echo "API not responding"
	@echo ""
	@echo "=== Services Status ==="
	$(DOCKER_COMPOSE) ps

# Utilitaires
update: ## Mettre à jour depuis git
	git pull
	$(DOCKER_COMPOSE) build
	$(DOCKER_COMPOSE) up -d

backup-all: ## Backup complet (DB + data)
	./scripts/backup.sh

clean-logs: ## Nettoyer les vieux logs
	find logs/ -name "*.log" -mtime +30 -delete
	@echo "Logs de plus de 30 jours supprimés"

disk-usage: ## Voir l'utilisation du disque
	@echo "=== Docker volumes ==="
	docker system df -v
	@echo ""
	@echo "=== Disk usage ==="
	df -h

portainer: ## Ouvrir Portainer dans le navigateur
	@echo "Portainer: http://localhost:9000"
	@command -v xdg-open >/dev/null 2>&1 && xdg-open http://localhost:9000 || open http://localhost:9000 || echo "Ouvrez manuellement: http://localhost:9000"
