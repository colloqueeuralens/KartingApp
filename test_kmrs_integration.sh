#!/bin/bash

# Script de test d'intégration pour la page Stratégie KMRS
echo "🧪 Test d'Intégration - Page Stratégie KMRS"
echo "=========================================="

# Vérifier que le fichier KMRS.xlsm existe
if [ ! -f "KMRS.xlsm" ]; then
    echo "❌ Erreur: Fichier KMRS.xlsm non trouvé dans le répertoire racine"
    echo "   Assurez-vous que le fichier est présent avant de continuer"
    exit 1
fi

echo "✅ Fichier KMRS.xlsm trouvé"

# Aller dans le répertoire backend
cd backend

# Vérifier les dépendances Python
echo ""
echo "🔍 Vérification des dépendances Python..."
python3 -c "import openpyxl; print('✅ openpyxl disponible')" 2>/dev/null || {
    echo "📦 Installation d'openpyxl..."
    pip install openpyxl==3.1.2
}

# Test 1: Parser Excel direct
echo ""
echo "📋 Test 1: Parser Excel Direct"
echo "------------------------------"
python3 test_kmrs_parser.py

if [ $? -eq 0 ]; then
    echo "✅ Test 1 réussi: Parser Excel fonctionne"
else
    echo "❌ Test 1 échoué: Problème avec le parser Excel"
    exit 1
fi

# Démarrer le backend en arrière-plan
echo ""
echo "🚀 Démarrage du backend FastAPI..."
echo "--------------------------------"

# Tuer tout processus uvicorn existant sur le port 8001
pkill -f "uvicorn.*8001" 2>/dev/null || true
sleep 2

# Démarrer le backend
nohup python3 -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8001 > backend.log 2>&1 &
BACKEND_PID=$!

echo "Backend démarré avec PID: $BACKEND_PID"
echo "Logs disponibles dans: backend/backend.log"

# Attendre que le backend soit prêt
echo "⏳ Attente que le backend soit opérationnel..."
for i in {1..10}; do
    if curl -s http://localhost:8001/health > /dev/null 2>&1; then
        echo "✅ Backend opérationnel"
        break
    fi
    echo "   Tentative $i/10..."
    sleep 2
done

# Vérifier si le backend répond
if ! curl -s http://localhost:8001/health > /dev/null 2>&1; then
    echo "❌ Impossible de joindre le backend après 20 secondes"
    echo "📋 Logs du backend:"
    tail -20 backend.log
    kill $BACKEND_PID 2>/dev/null
    exit 1
fi

# Test 2: Endpoints API
echo ""
echo "🌐 Test 2: Endpoints API"
echo "-----------------------"
python3 test_kmrs_endpoints.py

if [ $? -eq 0 ]; then
    echo "✅ Test 2 réussi: Endpoints API fonctionnent"
else
    echo "❌ Test 2 échoué: Problème avec les endpoints API"
fi

# Garder le backend actif pour les tests Flutter
echo ""
echo "🎯 Backend opérationnel pour tests Flutter"
echo "========================================="
echo "Le backend est maintenant opérationnel à: http://localhost:8001"
echo ""
echo "📱 Instructions pour tester avec Flutter:"
echo "1. Ouvrez l'application Flutter"
echo "2. Naviguez vers la page 'Stratégie'"
echo "3. Cliquez sur 'Test Backend' pour vérifier la connectivité"
echo "4. Cliquez sur 'Analyser KMRS.xlsm' pour parser le fichier"
echo "5. Vérifiez que les onglets des feuilles s'affichent"
echo ""
echo "🔧 Commandes utiles:"
echo "- Logs backend: tail -f backend/backend.log"
echo "- Santé backend: curl http://localhost:8001/health"
echo "- Arrêter backend: kill $BACKEND_PID"
echo ""
echo "💡 Appuyez sur Ctrl+C pour arrêter le backend"

# Fonction de nettoyage
cleanup() {
    echo ""
    echo "🧹 Nettoyage..."
    kill $BACKEND_PID 2>/dev/null
    echo "Backend arrêté"
    exit 0
}

# Capturer Ctrl+C
trap cleanup INT

# Attendre que l'utilisateur arrête le script
wait $BACKEND_PID