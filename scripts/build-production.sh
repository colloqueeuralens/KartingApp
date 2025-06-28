#!/bin/bash

# KMRS Racing - Script de Build Production
# Compile l'application Flutter pour production avec configuration VPS

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
DOMAIN=${DOMAIN:-"kmrs-racing.com"}
API_DOMAIN=${API_DOMAIN:-"api.kmrs-racing.com"}
BUILD_DIR="build"
APK_OUTPUT="$BUILD_DIR/android"
WEB_OUTPUT="$BUILD_DIR/web"

print_status() {
    echo -e "${GREEN}[BUILD]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo -e "${BLUE}🏗️ KMRS Racing - Production Build${NC}"
echo -e "${BLUE}==================================${NC}"

# Vérifier que Flutter est installé
if ! command -v flutter &> /dev/null; then
    print_error "Flutter n'est pas installé ou pas dans le PATH"
    exit 1
fi

# Nettoyer les builds précédents
print_status "Nettoyage des builds précédents..."
flutter clean
rm -rf $BUILD_DIR

# Récupérer les dépendances
print_status "Récupération des dépendances..."
flutter pub get

# Analyser le code
print_status "Analyse du code..."
flutter analyze

# Configuration pour production
print_status "Configuration pour production (domaine: $DOMAIN)..."

# Créer le fichier de configuration web
cat > web/index.html.template << 'EOF'
<!DOCTYPE html>
<html>
<head>
  <base href="$FLUTTER_BASE_HREF">
  <meta charset="UTF-8">
  <meta content="IE=Edge" http-equiv="X-UA-Compatible">
  <meta name="description" content="KMRS Racing - Application de gestion de karting">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black">
  <meta name="apple-mobile-web-app-title" content="KMRS Racing">
  <link rel="apple-touch-icon" href="icons/Icon-192.png">
  <link rel="icon" type="image/png" href="favicon.png"/>
  <title>KMRS Racing</title>
  <link rel="manifest" href="manifest.json">
  <script>
    window.flutterConfiguration = {
      canvasKitBaseUrl: "https://unpkg.com/canvaskit-wasm@0.38.0/bin/"
    };
  </script>
</head>
<body>
  <script>
    window.addEventListener('load', function(ev) {
      _flutter.loader.loadEntrypoint({
        serviceWorker: {
          serviceWorkerVersion: serviceWorkerVersion,
        },
        onEntrypointLoaded: function(engineInitializer) {
          engineInitializer.initializeEngine().then(function(appRunner) {
            appRunner.runApp();
          });
        }
      });
    });
  </script>
</body>
</html>
EOF

# Build Web pour production
print_status "Build Flutter Web pour production..."
flutter build web \
    --release \
    --web-renderer html \
    --dart-define=FLUTTER_WEB_BASE_URL=https://$DOMAIN \
    --dart-define=PRODUCTION_API_URL=https://$API_DOMAIN

# Build APK Android
print_status "Build APK Android..."
flutter build apk \
    --release \
    --dart-define=PRODUCTION_API_URL=https://$API_DOMAIN

# Créer les archives
print_status "Création des archives..."
mkdir -p $BUILD_DIR/archives

# Archive Web
cd $WEB_OUTPUT
tar -czf ..//archives/kmrs-racing-web-$(date +%Y%m%d-%H%M%S).tar.gz *
cd - > /dev/null

# Copier APK avec nom explicite
cp build/app/outputs/flutter-apk/app-release.apk \
   $BUILD_DIR/archives/kmrs-racing-$(date +%Y%m%d-%H%M%S).apk

# Générer un script de déploiement web
print_status "Génération du script de déploiement..."
cat > $BUILD_DIR/deploy-web.sh << EOF
#!/bin/bash

# Script de déploiement web automatique
# Usage: ./deploy-web.sh

echo "🚀 Déploiement KMRS Racing Web"

# Option 1: Firebase Hosting
if command -v firebase &> /dev/null; then
    echo "Déploiement sur Firebase Hosting..."
    firebase deploy --only hosting
    echo "✅ Déployé sur Firebase: https://$DOMAIN"
else
    echo "❌ Firebase CLI non installé"
fi

# Option 2: VPS via SCP
if [ ! -z "\$VPS_IP" ]; then
    echo "Déploiement sur VPS via SCP..."
    scp -r web/* root@\$VPS_IP:/var/www/kmrs-racing/
    echo "✅ Déployé sur VPS: https://$DOMAIN"
else
    echo "ℹ️ Définir VPS_IP pour déployer sur VPS"
fi

echo "🎉 Déploiement terminé!"
EOF

chmod +x $BUILD_DIR/deploy-web.sh

# Créer le README de déploiement
cat > $BUILD_DIR/README-DEPLOYMENT.md << EOF
# 📦 KMRS Racing - Builds de Production

Builds générés le: $(date)
Domaine configuré: $DOMAIN
API configurée: $API_DOMAIN

## 📱 APK Android

\`\`\`bash
# Installer l'APK sur Android
adb install kmrs-racing-*.apk

# Ou transférer manuellement et installer
\`\`\`

## 🌐 Application Web

### Option 1: Firebase Hosting
\`\`\`bash
# Déployer sur Firebase
firebase deploy --only hosting

# URL: https://$DOMAIN
\`\`\`

### Option 2: VPS Manuel
\`\`\`bash
# Copier les fichiers web sur le VPS
scp -r web/* root@[VPS_IP]:/var/www/kmrs-racing/

# URL: https://$DOMAIN
\`\`\`

### Option 3: Script Automatique
\`\`\`bash
# Utiliser le script de déploiement
./deploy-web.sh
\`\`\`

## 🔧 Configuration

L'application est configurée pour:
- **Environnement**: Production
- **API Backend**: https://$API_DOMAIN
- **WebSocket**: wss://$API_DOMAIN
- **Firebase**: kartingapp-fef5c

## 📊 Vérification

Après déploiement, vérifier:
- https://$DOMAIN (application web)
- https://$API_DOMAIN/health (santé API)
- WebSocket live timing fonctionnel

## 🚨 Dépannage

Si l'application ne se connecte pas:
1. Vérifier que le VPS est démarré
2. Vérifier les certificats SSL
3. Tester l'API: curl https://$API_DOMAIN/health
4. Vérifier les logs: docker-compose logs
EOF

# Afficher le résumé
print_status "✅ Build de production terminé!"
echo
echo -e "${GREEN}📦 Fichiers générés:${NC}"
echo "  📱 APK Android: $BUILD_DIR/archives/kmrs-racing-*.apk"
echo "  🌐 Web Archive: $BUILD_DIR/archives/kmrs-racing-web-*.tar.gz"
echo "  📁 Web Files: $WEB_OUTPUT/"
echo "  🚀 Deploy Script: $BUILD_DIR/deploy-web.sh"
echo "  📖 Instructions: $BUILD_DIR/README-DEPLOYMENT.md"
echo
echo -e "${BLUE}🎯 Prochaines étapes:${NC}"
echo "1. Déployer le backend sur VPS (voir deployment/README.md)"
echo "2. Déployer le web: $BUILD_DIR/deploy-web.sh"
echo "3. Installer l'APK sur Android"
echo "4. Tester l'accès global: https://$DOMAIN"
echo
echo -e "${GREEN}🏁 Votre application est prête pour la production!${NC}"