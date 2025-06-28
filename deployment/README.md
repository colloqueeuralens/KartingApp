# 🏁 KMRS Racing - Guide de Déploiement VPS

Ce guide vous accompagne pas à pas pour déployer l'application KMRS Racing sur un VPS avec accès mondial.

## 🎯 Architecture de Production

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Flutter Web   │    │       VPS        │    │    Firebase     │
│ (Firebase Host) │────│   NGINX + API    │────│   (Firestore)   │
│                 │    │  PostgreSQL+Redis│    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 📋 Prérequis

### 1. VPS Recommandés
- **Hetzner Cloud**: 2 vCPU, 4GB RAM (~12€/mois) ⭐ **Recommandé**
- **DigitalOcean**: 2 vCPU, 4GB RAM (~25€/mois)
- **Contabo**: 4 vCPU, 8GB RAM (~8€/mois)

### 2. Nom de Domaine
- Acheter un domaine (ex: `kmrs-racing.com`)
- Configurer DNS vers IP du VPS :
  ```
  A    @              → [IP_VPS]
  A    api            → [IP_VPS]
  CNAME www           → kmrs-racing.com
  ```

## 🚀 Installation Automatique

### Étape 1: Connexion VPS

```bash
# Connexion SSH au VPS
ssh root@[IP_VPS]

# Télécharger le script d'installation
wget https://raw.githubusercontent.com/colloqueeuralens/KartingApp/main/backend/scripts/setup-vps.sh
chmod +x setup-vps.sh

# Configurer les variables d'environnement
export DOMAIN="kmrs-racing.com"
export API_DOMAIN="api.kmrs-racing.com"
export SSL_EMAIL="votre-email@example.com"

# Lancer l'installation
./setup-vps.sh
```

### Étape 2: Configuration de l'Application

```bash
# Passer à l'utilisateur karting
su - karting
cd /opt/karting-app

# Cloner le projet
git clone https://github.com/colloqueeuralens/KartingApp.git .

# Configurer l'environnement
cp backend/.env.prod.example .env
nano .env
```

**Configuration `.env` :**
```bash
# Database
POSTGRES_PASSWORD=motdepasse_database_ultra_securise_ici
REDIS_PASSWORD=motdepasse_redis_securise_ici

# Security
SECRET_KEY=cle_secrete_jwt_minimum_32_caracteres_aleatoires

# Domain
DOMAIN=votre-domaine.com
API_DOMAIN=api.votre-domaine.com
SSL_EMAIL=votre-email@example.com

# Firebase
FIREBASE_PROJECT_ID=kartingapp-fef5c
```

### Étape 3: Copier les Credentials Firebase

```bash
# Copier le fichier firebase-credentials.json
scp firebase-credentials.json root@[IP_VPS]:/opt/karting-app/backend/
```

### Étape 4: Obtenir les Certificats SSL

```bash
# Sur le VPS
su - karting
cd /opt/karting-app
./setup-ssl.sh
```

### Étape 5: Déploiement

```bash
# Déployer l'application
./deploy.sh
```

## 🔧 Configuration Flutter Web

### Modifier l'URL du Backend

```dart
// lib/services/backend_service.dart
class BackendService {
  static const String _baseUrl = 'https://api.votre-domaine.com';
  static const String _wsBaseUrl = 'wss://api.votre-domaine.com';
  // ...
}
```

### Build et Déploiement Web

```bash
# Build Flutter Web
flutter build web --release --web-renderer html

# Déployer sur Firebase
firebase deploy --only hosting
```

## 📱 Configuration Mobile

### Option 1: APK Android

```bash
# Build APK
flutter build apk --release

# L'APK sera dans build/app/outputs/flutter-apk/app-release.apk
# Transférer sur téléphone et installer
```

### Option 2: PWA (Progressive Web App)

L'application web est automatiquement installable comme PWA depuis le navigateur mobile.

## 🛠 Commandes de Gestion

### Gestion des Services

```bash
# Voir le statut
docker-compose ps

# Voir les logs
docker-compose logs -f

# Redémarrer l'API
docker-compose restart api

# Mise à jour complète
./deploy.sh
```

### Surveillance

```bash
# Logs en temps réel
docker-compose logs -f api

# Espace disque
df -h

# Utilisation mémoire
docker stats

# Santé de l'API
curl https://api.votre-domaine.com/health
```

### Sauvegardes

```bash
# Backup manuel de la base
/opt/karting-app/scripts/backup.sh

# Voir les backups
ls -la /opt/karting-app/backups/

# Restaurer un backup
docker exec -i karting_postgres_prod psql -U timing_user timing_db < backup_file.sql
```

## 🌍 Accès Global

Une fois déployé, votre application sera accessible partout dans le monde :

- **URL Web**: `https://votre-domaine.com`
- **API**: `https://api.votre-domaine.com`
- **Mobile**: PWA installable ou APK

## 🔒 Sécurité

### Certificats SSL
- Certificats Let's Encrypt gratuits
- Renouvellement automatique
- Redirection HTTP → HTTPS

### Firewall
- Ports 22 (SSH), 80 (HTTP), 443 (HTTPS) ouverts
- Fail2ban configuré contre les attaques
- Rate limiting sur l'API

### Base de Données
- PostgreSQL non exposé publiquement
- Mots de passe sécurisés
- Backups automatiques quotidiens

## 📊 Monitoring

### Logs Disponibles
- API: `/opt/karting-app/logs/`
- NGINX: `/opt/karting-app/nginx/logs/`
- Base: `docker-compose logs postgres`

### Métriques
- Health check: `https://api.votre-domaine.com/health`
- Statut services: `docker-compose ps`
- Utilisation ressources: `htop`, `docker stats`

## 🚨 Dépannage

### Problèmes Courants

**API non accessible :**
```bash
# Vérifier les services
docker-compose ps
docker-compose logs api

# Vérifier NGINX
docker-compose logs nginx
```

**Certificats SSL expirés :**
```bash
# Renouveler manuellement
certbot renew --force-renewal
docker-compose restart nginx
```

**Base de données corrompue :**
```bash
# Restaurer depuis backup
ls /opt/karting-app/backups/
# Suivre la procédure de restauration
```

## 💰 Coûts Mensuels Estimés

- **VPS Hetzner**: ~12€/mois
- **Domaine**: ~1€/mois
- **Firebase**: Gratuit (usage normal)
- **Total**: ~13€/mois

## 📞 Support

En cas de problème :
1. Consulter les logs : `docker-compose logs`
2. Vérifier la documentation
3. Contacter l'équipe de développement

---

**🏁 Votre application de karting est maintenant accessible dans le monde entier !**