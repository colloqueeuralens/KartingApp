# 🚀 KMRS Racing - Guide de Déploiement Express

Guide rapide pour déployer l'application sur VPS avec accès mondial en 30 minutes.

## 🎯 Résultat Final

Après ce guide, vous aurez :
- ✅ Application accessible partout dans le monde
- ✅ URL fixe : `https://votre-domaine.com`
- ✅ API backend sécurisée : `https://api.votre-domaine.com`
- ✅ APK Android fonctionnel
- ✅ Certificats SSL automatiques
- ✅ Backups automatiques

## 📋 Checklist Avant Démarrage

- [ ] VPS acheté et accessible via SSH
- [ ] Nom de domaine acheté
- [ ] Fichier `firebase-credentials.json` disponible
- [ ] Git/Flutter installés sur votre machine

## ⚡ Déploiement Express (30 min)

### 🌐 Étape 1: Configuration DNS (5 min)

Dans votre gestionnaire de domaine, créer ces enregistrements :

```
Type  Nom   Valeur
A     @     [IP_DE_VOTRE_VPS]
A     api   [IP_DE_VOTRE_VPS]
CNAME www   votre-domaine.com
```

### 🖥️ Étape 2: Setup VPS Automatique (10 min)

```bash
# 1. Se connecter au VPS
ssh root@[IP_VPS]

# 2. Télécharger et lancer l'installation automatique
curl -fsSL https://raw.githubusercontent.com/colloqueeuralens/KartingApp/main/backend/scripts/setup-vps.sh -o setup-vps.sh
chmod +x setup-vps.sh

# 3. Configurer et lancer (remplacer par votre domaine)
export DOMAIN="votre-domaine.com"
export API_DOMAIN="api.votre-domaine.com"  
export SSL_EMAIL="votre-email@example.com"
./setup-vps.sh

# 4. Passer à l'utilisateur karting
su - karting
cd /opt/karting-app
```

### 📂 Étape 3: Configuration Application (10 min)

```bash
# 1. Cloner le projet
git clone https://github.com/colloqueeuralens/KartingApp.git .

# 2. Créer la configuration
cp backend/.env.prod.example .env
nano .env
```

**Configurer `.env` (valeurs importantes) :**
```bash
POSTGRES_PASSWORD=motdepasse_database_ultra_securise_ici
REDIS_PASSWORD=motdepasse_redis_securise_ici
SECRET_KEY=cle_secrete_jwt_minimum_32_caracteres_aleatoires
DOMAIN=votre-domaine.com
API_DOMAIN=api.votre-domaine.com
SSL_EMAIL=votre-email@example.com
```

```bash
# 3. Copier les credentials Firebase
# (Depuis votre machine locale)
scp firebase-credentials.json karting@[IP_VPS]:/opt/karting-app/backend/

# 4. Obtenir les certificats SSL
./setup-ssl.sh

# 5. Déployer l'application
./deploy.sh
```

### 📱 Étape 4: Build Applications (5 min)

```bash
# Sur votre machine locale
cd karting_app/

# Configurer le domaine et builder
export DOMAIN="votre-domaine.com"
export API_DOMAIN="api.votre-domaine.com"
./scripts/build-production.sh

# Déployer le web
cd build/
./deploy-web.sh
```

## ✅ Vérification du Déploiement

### Tests Automatiques

```bash
# 1. Santé de l'API
curl https://api.votre-domaine.com/health

# 2. Application web
curl -I https://votre-domaine.com

# 3. WebSocket (depuis l'app)
# Le live timing doit fonctionner
```

### Tests Manuels

1. **Web** : Ouvrir `https://votre-domaine.com`
2. **Mobile** : Installer l'APK ou accéder via navigateur
3. **Live Timing** : Tester avec un circuit configuré

## 🛠 Commandes de Maintenance

```bash
# SSH vers le VPS
ssh karting@[IP_VPS]
cd /opt/karting-app

# Voir les logs
docker-compose logs -f

# Redémarrer
docker-compose restart

# Mise à jour
git pull origin main
./deploy.sh

# Backup manuel
./scripts/backup.sh
```

## 🔧 Configuration Recommandée VPS

### Providers Testés

| Provider | Config | Prix/mois | Performance |
|----------|--------|-----------|-------------|
| **Hetzner** ⭐ | 2 vCPU, 4GB | ~12€ | Excellente |
| DigitalOcean | 2 vCPU, 4GB | ~25€ | Très bonne |
| Contabo | 4 vCPU, 8GB | ~8€ | Bonne |

### OS Recommandé
- **Ubuntu 22.04 LTS** (testé et supporté)

## 🚨 Dépannage Express

### Problème : API non accessible

```bash
# Vérifier les services
docker-compose ps
docker-compose logs api

# Redémarrer si nécessaire
docker-compose restart api
```

### Problème : SSL ne fonctionne pas

```bash
# Vérifier les certificats
certbot certificates

# Renouveler si nécessaire
certbot renew --force-renewal
docker-compose restart nginx
```

### Problème : Application ne charge pas

```bash
# Vérifier NGINX
docker-compose logs nginx

# Vérifier les DNS
nslookup votre-domaine.com
```

## 📞 Support d'Urgence

Si vous êtes bloqué :

1. **Logs détaillés** : `docker-compose logs > logs-debug.txt`
2. **État services** : `docker-compose ps > services-status.txt`
3. **Configuration** : `cat .env > config-sanitized.txt` (sans les mots de passe)

## 💰 Coût Total Estimé

- **VPS Hetzner** : 12€/mois
- **Domaine** : 10€/an (~1€/mois)
- **SSL** : Gratuit (Let's Encrypt)
- **Firebase** : Gratuit (usage normal)

**Total : ~13€/mois pour un accès mondial professionnel** 🌍

---

## 🏁 Résultat Final

Après ce guide, votre application KMRS Racing sera :

✅ **Accessible partout dans le monde**  
✅ **Sécurisée avec HTTPS**  
✅ **Haute disponibilité 24/7**  
✅ **Sauvegardée automatiquement**  
✅ **Scalable selon vos besoins**  

**Plus besoin de configuration réseau sur les circuits !**  
Ouvrez simplement `https://votre-domaine.com` sur n'importe quel appareil. 🎉