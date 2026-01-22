# 🚀 Guide de démarrage rapide - Oracle Cloud

## Étape 1 : Créer l'instance Oracle Cloud

1. Connectez-vous à https://cloud.oracle.com
2. Menu → Compute → Instances → Create Instance
3. Configuration :
   - **Name**: email-agent-vm
   - **Image**: Ubuntu 22.04 (ARM)
   - **Shape**: VM.Standard.A1.Flex
   - **OCPU**: 4
   - **Memory**: 24 GB
   - **Boot Volume**: 100 GB
4. Add SSH keys (générer si nécessaire)
5. Create

## Étape 2 : Configurer la sécurité réseau

1. Dans votre instance, cliquer sur le subnet
2. Security Lists → Default Security List
3. Add Ingress Rules :

```
Source CIDR: 0.0.0.0/0
Destination Port: 80
Description: HTTP

Source CIDR: 0.0.0.0/0
Destination Port: 443
Description: HTTPS

Source CIDR: 0.0.0.0/0
Destination Port: 9000
Description: Portainer
```

## Étape 3 : Connexion et installation

```bash
# Récupérer l'IP publique de votre instance
# Connexion SSH
ssh ubuntu@<VOTRE_IP_PUBLIQUE>

# Cloner le repo
git clone https://github.com/VOTRE-USERNAME/email-agent.git
cd email-agent

# Lancer l'installation (prend ~5-10 minutes)
chmod +x scripts/setup-oracle.sh
sudo ./scripts/setup-oracle.sh
```

## Étape 4 : Configuration

```bash
# Éditer la configuration
nano .env

# Changer au minimum:
# - ADMIN_EMAIL
# - ADMIN_PASSWORD
```

## Étape 5 : Démarrage

```bash
# Démarrer tous les services
docker-compose up -d

# Télécharger le modèle Ollama (IMPORTANT - prend 5-10 min)
docker-compose exec ollama ollama pull mistral

# Vérifier que tout fonctionne
docker-compose ps
docker-compose logs -f
```

## Étape 6 : Premier accès

```bash
# Récupérer votre IP publique
curl ifconfig.me
```

Accéder à :
- **API**: http://<VOTRE_IP>
- **Portainer**: http://<VOTRE_IP>:9000

## Commandes utiles

```bash
# Voir les logs
docker-compose logs -f

# Redémarrer un service
docker-compose restart api

# Arrêter tout
docker-compose down

# Backup manuel
./scripts/backup.sh

# Restaurer un backup
./scripts/restore.sh /var/backups/email-agent/backup-20250120.tar.gz

# Vérifier l'espace disque
df -h

# Voir les stats Docker
docker stats
```

## Problèmes courants

### Ollama ne répond pas

```bash
# Vérifier les logs
docker-compose logs ollama

# Redémarrer Ollama
docker-compose restart ollama

# Vérifier que le modèle est téléchargé
docker-compose exec ollama ollama list
```

### Base de données n'est pas prête

```bash
# Attendre que PostgreSQL soit prêt
docker-compose logs db

# Si nécessaire, recréer la base
docker-compose down
docker volume rm email-agent_pgdata
docker-compose up -d
```

### Problème de mémoire

```bash
# Vérifier la RAM
free -h

# Limiter la mémoire d'Ollama dans docker-compose.yml
# Changer deploy.resources.limits.memory à 8G
```

## Configuration SSL (optionnel)

Si vous avez un nom de domaine :

```bash
# Installer Certbot
sudo apt install certbot python3-certbot-nginx

# Obtenir un certificat
sudo certbot --nginx -d votre-domaine.com

# Le renouvellement automatique est déjà configuré
```

## Monitoring

### Portainer
- URL: http://<IP>:9000
- Gérer tous les containers
- Voir logs en temps réel
- Stats de ressources

### Logs
```bash
# Logs de l'API
docker-compose logs -f api

# Logs du worker
docker-compose logs -f worker

# Tous les logs
docker-compose logs -f
```

## Prochaines étapes

1. Ajouter votre premier compte email via l'API
2. Tester la classification
3. Configurer les règles personnalisées
4. Ajuster les paramètres dans .env

## Support

- Documentation complète : voir README.md
- Logs : `/app/logs/` dans les containers
- Backups : `/var/backups/email-agent/`
