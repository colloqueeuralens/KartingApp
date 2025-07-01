# Configuration Firebase Hosting avec domaine kmrs-racing.eu

Ce guide explique comment connecter votre domaine personnalisé `kmrs-racing.eu` à Firebase Hosting.

## Étape 1: Configuration DNS

### Chez votre registraire de domaine (où vous avez acheté kmrs-racing.eu)

Configurez les enregistrements DNS suivants :

```
# Frontend sur Firebase Hosting
kmrs-racing.eu        A     151.101.1.195  (ou suivre les instructions Firebase)
kmrs-racing.eu        A     151.101.65.195
www.kmrs-racing.eu    CNAME kmrs-racing.eu

# Backend sur VPS
api.kmrs-racing.eu    A     [IP_DE_VOTRE_VPS]
```

## Étape 2: Configuration Firebase Hosting

### Dans la console Firebase (console.firebase.google.com)

1. **Aller dans Hosting**
   - Projet: `kartingapp-fef5c`
   - Section "Hosting"

2. **Ajouter un domaine personnalisé**
   - Cliquer "Ajouter un domaine personnalisé"
   - Saisir: `kmrs-racing.eu`
   - Suivre les instructions de vérification

3. **Vérification du domaine**
   - Firebase vous donnera un code TXT à ajouter dans vos DNS
   - Ajouter l'enregistrement TXT chez votre registraire
   - Attendre la validation (peut prendre jusqu'à 24h)

4. **Configuration automatique SSL**
   - Firebase configure automatiquement les certificats SSL
   - Le domaine sera accessible en HTTPS

## Étape 3: Build et déploiement avec nouvelle configuration

### Mise à jour de la configuration

Le fichier `lib/config/app_config.dart` est déjà configuré pour détecter automatiquement l'environnement de production.

### Build production

```bash
# Build pour production avec détection automatique
flutter build web --release

# Deploy sur Firebase Hosting
firebase deploy --only hosting
```

### Vérification

Une fois déployé, votre application sera accessible sur :
- `https://kmrs-racing.eu` (domaine principal)
- `https://kartingapp-fef5c.web.app` (domaine Firebase par défaut)

## Étape 4: Configuration backend VPS

### Déploiement automatique

```bash
# Depuis le répertoire backend/
cd backend
./scripts/deploy-vps.sh kmrs-racing.eu [IP_VPS]
```

### Configuration manuelle DNS API

Chez votre registraire, ajouter :
```
api.kmrs-racing.eu    A    [IP_DE_VOTRE_VPS]
```

## Étape 5: Tests de bout en bout

### Vérifications

1. **Frontend accessible** : https://kmrs-racing.eu
2. **API accessible** : https://api.kmrs-racing.eu/health
3. **CORS fonctionnel** : Pas d'erreurs CORS dans la console
4. **WebSocket** : Live timing fonctionne
5. **Synchronisation** : Données synchronisées web ↔ mobile

### Debug en cas de problème

```bash
# Vérifier les DNS
nslookup kmrs-racing.eu
nslookup api.kmrs-racing.eu

# Tester l'API
curl https://api.kmrs-racing.eu/health

# Tester CORS
curl -H "Origin: https://kmrs-racing.eu" -H "Access-Control-Request-Method: GET" -X OPTIONS https://api.kmrs-racing.eu/

# Logs VPS
ssh root@[IP_VPS] 'cd /opt/kmrs-racing && docker compose logs'
```

## Architecture finale

```
┌─────────────────────┐    ┌──────────────────────┐    ┌─────────────────┐
│   https://          │    │   https://           │    │    Firebase     │
│ kmrs-racing.eu      │────│ api.kmrs-racing.eu   │────│   Firestore     │
│ (Firebase Hosting)  │    │     (VPS)            │    │     Auth        │
│  Flutter Web PWA    │    │ FastAPI + NGINX + SSL│    │                 │
└─────────────────────┘    └──────────────────────┘    └─────────────────┘
```

## Avantages de cette configuration

- ✅ **Performance maximale** : CDN Firebase pour le frontend
- ✅ **SSL automatique** : HTTPS partout sans configuration manuelle
- ✅ **Domaine professionnel** : Votre propre domaine
- ✅ **Évolutivité** : Backend VPS indépendant
- ✅ **Coût optimisé** : Firebase Hosting quasi-gratuit
- ✅ **Monitoring** : Logs et métriques séparés
- ✅ **Backup** : Sauvegardes automatiques backend

## Support

En cas de problème :
1. Vérifier les DNS avec `nslookup`
2. Vérifier les logs Firebase Hosting
3. Vérifier les logs VPS : `docker compose logs`
4. Tester l'API directement avec `curl`