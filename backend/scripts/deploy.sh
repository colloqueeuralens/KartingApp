#!/bin/bash

# KMRS Racing - Deployment Script
# Automated deployment script for production VPS

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
APP_DIR="/opt/karting-app"
REPO_URL="https://github.com/colloqueeuralens/KartingApp.git"
BRANCH="main"
COMPOSE_FILE="docker-compose.prod.yml"

print_status() {
    echo -e "${GREEN}[DEPLOY]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo -e "${BLUE}🚀 KMRS Racing Deployment${NC}"
echo -e "${BLUE}========================${NC}"

# Check if .env file exists
if [ ! -f "$APP_DIR/.env" ]; then
    print_error ".env file not found in $APP_DIR"
    print_warning "Please create .env file from .env.prod.example and configure it"
    exit 1
fi

# Check if Firebase credentials exist
if [ ! -f "$APP_DIR/backend/firebase-credentials.json" ]; then
    print_error "Firebase credentials not found"
    print_warning "Please copy firebase-credentials.json to $APP_DIR/backend/"
    exit 1
fi

cd $APP_DIR

# Backup current deployment
if [ -d "backend" ]; then
    print_status "Creating backup of current deployment..."
    BACKUP_DIR="backups/deployment_$(date +%Y%m%d_%H%M%S)"
    mkdir -p $BACKUP_DIR
    cp -r backend $BACKUP_DIR/ 2>/dev/null || true
    cp docker-compose.yml $BACKUP_DIR/ 2>/dev/null || true
fi

# Pull latest code
print_status "Pulling latest code from GitHub..."
if [ -d ".git" ]; then
    git fetch origin
    git reset --hard origin/$BRANCH
    git clean -fd
else
    print_status "Cloning repository..."
    git clone -b $BRANCH $REPO_URL .
fi

# Copy production configuration
print_status "Setting up production configuration..."
cp backend/$COMPOSE_FILE docker-compose.yml

# Load environment variables
print_status "Loading environment variables..."
set -a
source .env
set +a

# Stop current services
print_status "Stopping current services..."
docker-compose down || true

# Build new images
print_status "Building application images..."
docker-compose build --no-cache --pull

# Start database and redis first
print_status "Starting database services..."
docker-compose up -d postgres redis

# Wait for database to be ready
print_status "Waiting for database to be ready..."
timeout=60
while ! docker-compose exec -T postgres pg_isready -U $POSTGRES_USER -d $POSTGRES_DB; do
    sleep 2
    timeout=$((timeout - 2))
    if [ $timeout -le 0 ]; then
        print_error "Database failed to start within 60 seconds"
        exit 1
    fi
done

# Run database migrations if needed
print_status "Running database migrations..."
# Add your migration commands here if you have any
# docker-compose exec -T api alembic upgrade head

# Start all services
print_status "Starting all services..."
docker-compose up -d

# Wait for API to be ready
print_status "Waiting for API to be ready..."
timeout=60
while ! docker-compose exec -T api curl -f http://localhost:8000/health &>/dev/null; do
    sleep 2
    timeout=$((timeout - 2))
    if [ $timeout -le 0 ]; then
        print_error "API failed to start within 60 seconds"
        docker-compose logs api
        exit 1
    fi
done

# Verify deployment
print_status "Verifying deployment..."
if docker-compose ps | grep -q "Up"; then
    print_status "✅ Deployment successful!"
    
    echo
    echo -e "${GREEN}🎉 Deployment Complete!${NC}"
    echo -e "${BLUE}Services Status:${NC}"
    docker-compose ps
    
    echo
    echo -e "${BLUE}Application URLs:${NC}"
    echo "  🌐 Main App: https://$DOMAIN"
    echo "  🔌 API: https://$API_DOMAIN"
    echo "  ❤️ Health: https://$API_DOMAIN/health"
    
    echo
    echo -e "${BLUE}Useful Commands:${NC}"
    echo "  📊 View logs: docker-compose logs -f"
    echo "  📈 View status: docker-compose ps"
    echo "  🔄 Restart: docker-compose restart"
    echo "  💾 Backup DB: $APP_DIR/scripts/backup.sh"
    
else
    print_error "❌ Deployment failed!"
    echo -e "${RED}Service Status:${NC}"
    docker-compose ps
    echo
    echo -e "${RED}Recent Logs:${NC}"
    docker-compose logs --tail=50
    exit 1
fi

# Clean up old images
print_status "Cleaning up old Docker images..."
docker image prune -f

print_status "Deployment completed successfully! 🏁"