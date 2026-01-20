# 🚀 Push vers GitHub - Guide Rapide

## Option 1 : Script automatique (Recommandé)

```bash
# Depuis le répertoire email-agent
./scripts/init-git-repo.sh VOTRE-USERNAME-GITHUB

# Le script fait tout automatiquement !
```

## Option 2 : Manuellement

### 1. Créer le repo sur GitHub

1. Aller sur https://github.com/new
2. **Repository name**: `email-agent`
3. **Description**: `🤖 AI-powered email management system with multi-account support`
4. **Public** ou **Private** (au choix)
5. ⚠️ **NE PAS** initialiser avec README, .gitignore ou licence
6. Cliquer sur **Create repository**

### 2. Initialiser Git localement

```bash
# Depuis le répertoire email-agent

# Initialiser le repo
git init

# Vérifier que .gitignore est là
ls -la .gitignore

# Ajouter tous les fichiers
git add .

# Commit initial
git commit -m "feat: Initial commit - Email Agent AI v1.0.0

Complete production-ready email management system:
- Docker infrastructure (PostgreSQL, Redis, Ollama, Nginx)
- FastAPI backend with full REST API
- Celery workers for async processing
- AI classification with Ollama
- Oracle Cloud deployment automation
- Comprehensive documentation

Ready to deploy on Oracle Cloud Free Tier."
```

### 3. Pousser vers GitHub

```bash
# Remplacer VOTRE-USERNAME par votre username GitHub
git remote add origin https://github.com/VOTRE-USERNAME/email-agent.git

# Pousser
git branch -M main
git push -u origin main
```

### 4. Configurer le repo sur GitHub

Une fois poussé, aller sur votre repo GitHub et :

#### Description et topics
- **Description**: `🤖 AI-powered email management system with Ollama LLM - Self-hosted, privacy-first, runs on Oracle Cloud Free Tier`
- **Topics** (en bas de page, cliquer "Add topics"):
  - `email-automation`
  - `ai-classification`
  - `llm`
  - `ollama`
  - `fastapi`
  - `docker`
  - `oracle-cloud`
  - `self-hosted`
  - `privacy`
  - `python`

#### Settings du repo
1. Aller dans **Settings** → **General**
2. **Features**:
   - ✅ Issues
   - ✅ Projects
   - ✅ Discussions (optionnel)
   - ✅ Wiki (optionnel)
3. **Pull Requests**:
   - ✅ Allow squash merging
   - ✅ Automatically delete head branches

#### GitHub Actions
Les workflows sont déjà configurés dans `.github/workflows/tests.yml`

Pour activer :
1. Aller dans **Actions**
2. Cliquer sur "I understand my workflows, go ahead and enable them"

#### Branch protection (optionnel mais recommandé)
1. **Settings** → **Branches**
2. **Add rule**
3. Branch name pattern: `main`
4. Cocher:
   - ✅ Require a pull request before merging
   - ✅ Require status checks to pass before merging
   - ✅ Require conversation resolution before merging

## Vérification

Après le push, vérifiez que tout est OK :

✅ **Code source** visible sur GitHub  
✅ **README.md** s'affiche bien avec badges  
✅ **GitHub Actions** lancée (onglet Actions)  
✅ **Issues** templates configurés  
✅ **License MIT** reconnue  

## Partager votre projet

### README badge
Ajoutez ce badge à votre README personnel :

```markdown
[![Email Agent AI](https://img.shields.io/badge/Email%20Agent%20AI-v1.0.0-blue?logo=github)](https://github.com/VOTRE-USERNAME/email-agent)
```

### Social
Partagez sur :
- Twitter/X avec #SelfHosted #AI #EmailAutomation
- Reddit: r/selfhosted, r/docker, r/FastAPI
- Hacker News
- LinkedIn

### Star et Watch
N'oubliez pas de mettre une ⭐ à votre propre repo pour le promouvoir !

## Contribuer

Le repo est maintenant prêt à recevoir des contributions. Invitez des collaborateurs ou acceptez des Pull Requests !

## Support

Si vous rencontrez des problèmes :
1. Vérifier les logs: `git status`, `git log`
2. Vérifier l'authentification GitHub
3. Consulter https://docs.github.com/fr

---

Félicitations ! Votre projet est maintenant sur GitHub 🎉
