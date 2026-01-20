# Politique de Sécurité

## Versions supportées

Les versions suivantes d'Email Agent AI reçoivent des mises à jour de sécurité :

| Version | Supportée          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Signaler une vulnérabilité

Nous prenons la sécurité très au sérieux. Si vous découvrez une vulnérabilité de sécurité, merci de **ne pas** créer une issue publique.

### Comment signaler

Envoyez un email à : **security@votre-domaine.com** (remplacer par votre email)

Incluez dans votre rapport :

1. **Description** de la vulnérabilité
2. **Étapes pour reproduire** le problème
3. **Impact potentiel** de la vulnérabilité
4. **Suggestions de correction** (si vous en avez)

### À quoi s'attendre

- **Accusé de réception** : Nous vous répondrons dans les 48 heures
- **Analyse** : Nous analyserons le problème et vous tiendrons informé
- **Correction** : Nous travaillerons sur un correctif
- **Divulgation** : Nous coordonnerons avec vous la divulgation publique

### Politique de divulgation

- Nous vous demandons de ne pas divulguer publiquement la vulnérabilité avant qu'un correctif soit disponible
- Nous créditons publiquement les chercheurs en sécurité qui signalent des vulnérabilités de manière responsable
- Nous visons à publier un correctif dans les 90 jours suivant le rapport

## Bonnes pratiques de sécurité

Pour les utilisateurs d'Email Agent :

### Configuration

- **Changez immédiatement** les mots de passe par défaut (`ADMIN_PASSWORD`, `DB_PASSWORD`, etc.)
- **Générez des clés fortes** pour `SECRET_KEY` et `ENCRYPTION_KEY`
- **Activez SSL/HTTPS** en production
- **Limitez l'accès réseau** aux ports strictement nécessaires

### Déploiement

- **Maintenez à jour** Docker et les dépendances système
- **Surveillez les logs** pour détecter des activités suspectes
- **Faites des backups réguliers** et testez la restauration
- **Utilisez un firewall** (UFW recommandé)

### Credentials email

- **Chiffrez toujours** les credentials (fait automatiquement par le système)
- **Utilisez OAuth2** plutôt que mots de passe quand possible
- **Limitez les permissions** des comptes de service
- **Révoquez l'accès** immédiatement en cas de compromission

### Développement

- **Ne committez jamais** de secrets dans Git
- **Utilisez `.env`** pour les configurations sensibles
- **Scannez les dépendances** régulièrement (`pip-audit`, `safety`)
- **Activez dependabot** sur GitHub

## Vulnérabilités connues

Aucune vulnérabilité connue actuellement.

Les anciennes vulnérabilités corrigées seront listées ici avec leur CVE (si applicable).

## Bug Bounty

Nous n'avons pas actuellement de programme bug bounty, mais nous apprécions grandement les signalements responsables et créditons publiquement les contributeurs.

## Ressources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [FastAPI Security](https://fastapi.tiangolo.com/tutorial/security/)

---

Dernière mise à jour : 2025-01-20
