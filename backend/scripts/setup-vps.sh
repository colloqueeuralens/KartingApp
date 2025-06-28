#!/bin/bash

# KMRS Racing - VPS Setup Script
# This script sets up a production VPS for the karting application

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOMAIN=${DOMAIN:-"kmrs-racing.com"}
API_DOMAIN=${API_DOMAIN:-"api.kmrs-racing.com"}
SSL_EMAIL=${SSL_EMAIL:-"admin@${DOMAIN}"}
APP_USER="karting"
APP_DIR="/opt/karting-app"

echo -e "${BLUE}🏁 KMRS Racing VPS Setup Script${NC}"
echo -e "${BLUE}================================${NC}"

# Function to print status
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root"
   exit 1
fi

print_status "Starting VPS setup for KMRS Racing application..."

# Update system
print_status "Updating system packages..."
apt-get update && apt-get upgrade -y

# Install essential packages
print_status "Installing essential packages..."
apt-get install -y \
    curl \
    wget \
    git \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    ufw \
    htop \
    nano \
    fail2ban

# Install Docker
print_status "Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    print_status "Docker installed successfully"
else
    print_status "Docker already installed"
fi

# Create application user
print_status "Creating application user..."
if ! id "$APP_USER" &>/dev/null; then
    useradd -m -s /bin/bash $APP_USER
    usermod -aG docker $APP_USER
    print_status "User $APP_USER created and added to docker group"
else
    print_status "User $APP_USER already exists"
fi

# Create application directory
print_status "Creating application directory..."
mkdir -p $APP_DIR
chown $APP_USER:$APP_USER $APP_DIR

# Configure firewall
print_status "Configuring firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable
print_status "Firewall configured"

# Configure fail2ban
print_status "Configuring fail2ban..."
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log

[nginx-noscript]
enabled = true
port = http,https
filter = nginx-noscript
logpath = /var/log/nginx/access.log
maxretry = 6

[nginx-badbots]
enabled = true
port = http,https
filter = nginx-badbots
logpath = /var/log/nginx/access.log
maxretry = 2

[nginx-noproxy]
enabled = true
port = http,https
filter = nginx-noproxy
logpath = /var/log/nginx/access.log
maxretry = 2
EOF

systemctl enable fail2ban
systemctl start fail2ban
print_status "Fail2ban configured"

# Install Certbot for SSL certificates
print_status "Installing Certbot..."
if ! command -v certbot &> /dev/null; then
    snap install core; snap refresh core
    snap install --classic certbot
    ln -sf /snap/bin/certbot /usr/bin/certbot
    print_status "Certbot installed"
else
    print_status "Certbot already installed"
fi

# Create directories for the application
print_status "Creating application directories..."
mkdir -p $APP_DIR/{nginx,logs,backups,ssl}
mkdir -p /var/www/certbot
chown -R $APP_USER:$APP_USER $APP_DIR

# Set up log rotation
print_status "Setting up log rotation..."
cat > /etc/logrotate.d/karting-app << EOF
$APP_DIR/logs/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 $APP_USER $APP_USER
}

$APP_DIR/nginx/logs/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 $APP_USER $APP_USER
    postrotate
        docker exec karting_nginx_prod nginx -s reload 2>/dev/null || true
    endscript
}
EOF

# Create backup script
print_status "Creating backup script..."
cat > $APP_DIR/scripts/backup.sh << 'EOF'
#!/bin/bash

# KMRS Racing Database Backup Script
BACKUP_DIR="/opt/karting-app/backups"
DATE=$(date +%Y%m%d_%H%M%S)
POSTGRES_CONTAINER="karting_postgres_prod"

# Create backup
docker exec $POSTGRES_CONTAINER pg_dump -U timing_user timing_db > $BACKUP_DIR/backup_$DATE.sql

# Compress backup
gzip $BACKUP_DIR/backup_$DATE.sql

# Remove backups older than 30 days
find $BACKUP_DIR -name "backup_*.sql.gz" -mtime +30 -delete

echo "Backup completed: backup_$DATE.sql.gz"
EOF

chmod +x $APP_DIR/scripts/backup.sh
chown $APP_USER:$APP_USER $APP_DIR/scripts/backup.sh

# Add backup to crontab
print_status "Setting up automatic backups..."
(crontab -u $APP_USER -l 2>/dev/null; echo "0 2 * * * $APP_DIR/scripts/backup.sh") | crontab -u $APP_USER -

# Create deployment script
print_status "Creating deployment script..."
cat > $APP_DIR/deploy.sh << 'EOF'
#!/bin/bash

# KMRS Racing Deployment Script
APP_DIR="/opt/karting-app"
REPO_URL="https://github.com/colloqueeuralens/KartingApp.git"
BRANCH="main"

cd $APP_DIR

# Pull latest code
if [ -d ".git" ]; then
    git pull origin $BRANCH
else
    git clone -b $BRANCH $REPO_URL .
fi

# Copy production docker-compose
cp backend/docker-compose.prod.yml docker-compose.yml

# Build and deploy
docker-compose down
docker-compose build --no-cache
docker-compose up -d

echo "Deployment completed!"
EOF

chmod +x $APP_DIR/deploy.sh
chown $APP_USER:$APP_USER $APP_DIR/deploy.sh

# Create SSL certificate setup script
print_status "Creating SSL setup script..."
cat > $APP_DIR/setup-ssl.sh << EOF
#!/bin/bash

# SSL Certificate Setup for KMRS Racing
echo "Setting up SSL certificates..."

# Stop nginx if running
docker-compose down nginx 2>/dev/null || true

# Get certificates
certbot certonly --standalone --agree-tos --no-eff-email --email $SSL_EMAIL -d $DOMAIN -d $API_DOMAIN

# Start the application
docker-compose up -d

echo "SSL certificates obtained successfully!"
echo "Your application will be available at:"
echo "  - https://$DOMAIN"
echo "  - https://$API_DOMAIN"
EOF

chmod +x $APP_DIR/setup-ssl.sh
chown $APP_USER:$APP_USER $APP_DIR/setup-ssl.sh

# Set up automatic certificate renewal
print_status "Setting up automatic SSL renewal..."
(crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet --deploy-hook 'docker exec karting_nginx_prod nginx -s reload'") | crontab -

# Configure system limits
print_status "Configuring system limits..."
cat >> /etc/security/limits.conf << EOF
$APP_USER soft nofile 65536
$APP_USER hard nofile 65536
EOF

# Create systemd service for the application
print_status "Creating systemd service..."
cat > /etc/systemd/system/karting-app.service << EOF
[Unit]
Description=KMRS Racing Application
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=true
User=$APP_USER
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable karting-app

print_status "VPS setup completed successfully!"
echo
echo -e "${GREEN}🎉 VPS Setup Complete!${NC}"
echo -e "${BLUE}Next steps:${NC}"
echo "1. Copy your application code to $APP_DIR"
echo "2. Create .env file with your configuration"
echo "3. Copy Firebase credentials to $APP_DIR/backend/firebase-credentials.json"
echo "4. Run: sudo -u $APP_USER $APP_DIR/setup-ssl.sh"
echo "5. Run: sudo -u $APP_USER $APP_DIR/deploy.sh"
echo
echo -e "${YELLOW}Important:${NC}"
echo "- Point your DNS records to this server's IP"
echo "- Configure your .env file before deployment"
echo "- Make sure Firebase credentials are present"
echo
echo -e "${BLUE}Your application will be available at:${NC}"
echo "  - https://$DOMAIN"
echo "  - https://$API_DOMAIN"