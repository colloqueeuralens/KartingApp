#!/bin/bash

# Script de déploiement KMRS Racing sur VPS
# Usage: ./deploy-vps.sh [domain] [vps_ip]

set -e

DOMAIN=${1:-"kmrs-racing.eu"}
VPS_IP=${2:-""}
API_DOMAIN="api.$DOMAIN"

echo "🚀 Déploiement KMRS Racing VPS"
echo "Domain: $DOMAIN"
echo "API Domain: $API_DOMAIN"

# Vérifications préalables
if [ -z "$VPS_IP" ]; then
    echo "❌ Usage: $0 <domain> <vps_ip>"
    echo "Exemple: $0 kmrs-racing.eu 123.456.789.10"
    exit 1
fi

echo "📋 Vérification des prérequis..."

# Vérifier que Docker est installé sur le VPS
ssh root@$VPS_IP "docker --version" > /dev/null || {
    echo "❌ Docker n'est pas installé sur le VPS"
    echo "Installer Docker avec: curl -fsSL https://get.docker.com | sh"
    exit 1
}

# Vérifier que Docker Compose est installé
ssh root@$VPS_IP "docker compose version" > /dev/null || {
    echo "❌ Docker Compose n'est pas installé sur le VPS"
    exit 1
}

echo "✅ Prérequis validés"

# Créer le répertoire de l'application sur le VPS
echo "📁 Préparation de l'environnement VPS..."
ssh root@$VPS_IP "mkdir -p /opt/kmrs-racing/{nginx,logs,backups,ssl}"

# Copier les fichiers de configuration
echo "📤 Upload des fichiers de configuration..."
scp docker-compose.production.yml root@$VPS_IP:/opt/kmrs-racing/docker-compose.yml
scp nginx/nginx.conf root@$VPS_IP:/opt/kmrs-racing/nginx/
scp nginx/api.conf root@$VPS_IP:/opt/kmrs-racing/nginx/
scp .env.production.example root@$VPS_IP:/opt/kmrs-racing/.env.example

# Copier le Dockerfile et les sources
echo "📤 Upload du code source..."
scp -r ../app root@$VPS_IP:/opt/kmrs-racing/
scp ../Dockerfile root@$VPS_IP:/opt/kmrs-racing/
scp ../requirements.txt root@$VPS_IP:/opt/kmrs-racing/

# Configuration SSL avec Let's Encrypt
echo "🔒 Configuration SSL Let's Encrypt..."
ssh root@$VPS_IP << EOF
cd /opt/kmrs-racing

# Générer le certificat SSL initial
docker run --rm -v /etc/letsencrypt:/etc/letsencrypt -v /var/www/certbot:/var/www/certbot certbot/certbot certonly --webroot --webroot-path=/var/www/certbot --email admin@$DOMAIN --agree-tos --no-eff-email -d $API_DOMAIN

# Configuration du renouvellement automatique
echo "0 12 * * * /usr/bin/docker run --rm -v /etc/letsencrypt:/etc/letsencrypt -v /var/www/certbot:/var/www/certbot certbot/certbot renew --quiet" | crontab -
EOF

# Configuration de l'environnement
echo "⚙️ Configuration de l'environnement..."
ssh root@$VPS_IP << EOF
cd /opt/kmrs-racing

# Créer le fichier .env de production
if [ ! -f .env ]; then
    cp .env.example .env
    
    # Générer des mots de passe sécurisés
    POSTGRES_PASSWORD=\$(openssl rand -base64 32)
    REDIS_PASSWORD=\$(openssl rand -base64 32)
    
    # Remplacer les valeurs dans .env
    sed -i "s/CHANGE_ME_STRONG_PASSWORD/\$POSTGRES_PASSWORD/g" .env
    sed -i "s/CHANGE_ME_REDIS_PASSWORD/\$REDIS_PASSWORD/g" .env
    sed -i "s/admin@kmrs-racing.eu/admin@$DOMAIN/g" .env
    
    echo "✅ Fichier .env créé avec mots de passe sécurisés"
else
    echo "⚠️ Fichier .env existe déjà, pas de modification"
fi
EOF

# Build et démarrage des conteneurs
echo "🐳 Build et démarrage des conteneurs Docker..."
ssh root@$VPS_IP << EOF
cd /opt/kmrs-racing

# Build de l'image
docker compose build --no-cache

# Démarrage des services
docker compose up -d

# Attendre que les services soient prêts
echo "⏳ Attente du démarrage des services..."
sleep 30

# Vérifier que les services sont en cours d'exécution
docker compose ps

# Test de santé de l'API
if curl -f https://$API_DOMAIN/health > /dev/null 2>&1; then
    echo "✅ API accessible sur https://$API_DOMAIN"
else
    echo "⚠️ API pas encore accessible, vérifier les logs: docker compose logs"
fi
EOF

# Configuration du firewall
echo "🔥 Configuration du firewall..."
ssh root@$VPS_IP << EOF
# Installer UFW si pas installé
apt-get update && apt-get install -y ufw

# Configuration firewall
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

echo "✅ Firewall configuré"
EOF

# Configuration des sauvegardes automatiques
echo "💾 Configuration des sauvegardes..."
ssh root@$VPS_IP << EOF
# Script de sauvegarde PostgreSQL
cat > /opt/kmrs-racing/backup.sh << 'BACKUP_EOF'
#!/bin/bash
DATE=\$(date +%Y%m%d_%H%M%S)
docker exec kmrs_postgres pg_dump -U kmrs_user kmrs_racing > /opt/kmrs-racing/backups/backup_\$DATE.sql
find /opt/kmrs-racing/backups -name "backup_*.sql" -mtime +30 -delete
BACKUP_EOF

chmod +x /opt/kmrs-racing/backup.sh

# Programmer la sauvegarde quotidienne
echo "0 2 * * * /opt/kmrs-racing/backup.sh" | crontab -

echo "✅ Sauvegardes automatiques configurées"
EOF

# Tests finaux
echo "🧪 Tests de déploiement..."

# Test API
if curl -f https://$API_DOMAIN/health > /dev/null 2>&1; then
    echo "✅ API Health Check: OK"
else
    echo "❌ API Health Check: FAILED"
fi

# Test CORS
CORS_TEST=$(curl -s -H "Origin: https://$DOMAIN" -H "Access-Control-Request-Method: GET" -X OPTIONS https://$API_DOMAIN/ | grep -i "access-control-allow-origin" || echo "")
if [ ! -z "$CORS_TEST" ]; then
    echo "✅ CORS Configuration: OK"
else
    echo "❌ CORS Configuration: FAILED"
fi

echo ""
echo "🎉 Déploiement terminé!"
echo ""
echo "📋 Informations de déploiement:"
echo "• API Backend: https://$API_DOMAIN"
echo "• WebSocket: wss://$API_DOMAIN/ws"
echo "• Health Check: https://$API_DOMAIN/health"
echo ""
echo "📱 Configuration Frontend:"
echo "• Domaine principal: https://$DOMAIN (Firebase Hosting)"
echo "• URL Backend: https://$API_DOMAIN"
echo ""
echo "🔧 Commandes utiles:"
echo "• Logs: ssh root@$VPS_IP 'cd /opt/kmrs-racing && docker compose logs'"
echo "• Restart: ssh root@$VPS_IP 'cd /opt/kmrs-racing && docker compose restart'"
echo "• Update: ssh root@$VPS_IP 'cd /opt/kmrs-racing && docker compose pull && docker compose up -d'"
echo ""
echo "⚠️ N'oubliez pas de:"
echo "1. Configurer les DNS: $DOMAIN → Firebase, $API_DOMAIN → $VPS_IP"
echo "2. Deployer le frontend sur Firebase avec la nouvelle config"
echo "3. Tester la synchronisation web ↔ mobile"