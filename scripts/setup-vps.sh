#!/bin/bash
# =============================================================================
# Call Center System - Complete VPS Setup Script
# Ubuntu 24.04 LTS
# Installs: Asterisk 20 + Laravel + MySQL + PHP 8.3 + Composer + Node.js
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MYSQL_ROOT_PASSWORD="CallCenterRoot2024!"
MYSQL_DB="call_center"
MYSQL_USER="callcenter"
MYSQL_PASSWORD="CallCenter2024!"
SERVER_IP=$(hostname -I | awk '{print $1}')
LARAVEL_DIR="/var/www/call-center"
ASTERISK_RECORDING_DIR="/var/spool/asterisk/recording"

echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE}  Call Center System - VPS Setup             ${NC}"
echo -e "${BLUE}  Server IP: ${SERVER_IP}                    ${NC}"
echo -e "${BLUE}=============================================${NC}"

# =============================================================================
# STEP 1: System Update & Prerequisites
# =============================================================================
echo -e "\n${YELLOW}[1/8] Updating system and installing prerequisites...${NC}"

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get upgrade -y
apt-get install -y \
    software-properties-common \
    curl \
    wget \
    git \
    unzip \
    build-essential \
    libncurses5-dev \
    libssl-dev \
    libxml2-dev \
    libsqlite3-dev \
    uuid-dev \
    libjansson-dev \
    libedit-dev \
    pkg-config \
    autoconf \
    automake \
    libtool \
    sox \
    ffmpeg \
    ufw \
    supervisor \
    acl

echo -e "${GREEN}[1/8] Prerequisites installed.${NC}"

# =============================================================================
# STEP 2: Install MySQL 8
# =============================================================================
echo -e "\n${YELLOW}[2/8] Installing MySQL...${NC}"

apt-get install -y mysql-server

# Start MySQL
systemctl start mysql
systemctl enable mysql

# Secure MySQL and create database
mysql -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MYSQL_ROOT_PASSWORD}';
CREATE DATABASE IF NOT EXISTS ${MYSQL_DB} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'localhost' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON ${MYSQL_DB}.* TO '${MYSQL_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

echo -e "${GREEN}[2/8] MySQL installed and configured.${NC}"

# =============================================================================
# STEP 3: Install PHP 8.3 + Extensions
# =============================================================================
echo -e "\n${YELLOW}[3/8] Installing PHP 8.3...${NC}"

add-apt-repository -y ppa:ondrej/php
apt-get update -y
apt-get install -y \
    php8.3 \
    php8.3-fpm \
    php8.3-cli \
    php8.3-common \
    php8.3-mysql \
    php8.3-xml \
    php8.3-mbstring \
    php8.3-curl \
    php8.3-zip \
    php8.3-bcmath \
    php8.3-intl \
    php8.3-gd \
    php8.3-tokenizer \
    php8.3-fileinfo \
    php8.3-dom

echo -e "${GREEN}[3/8] PHP 8.3 installed.${NC}"

# =============================================================================
# STEP 4: Install Composer
# =============================================================================
echo -e "\n${YELLOW}[4/8] Installing Composer...${NC}"

curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

echo -e "${GREEN}[4/8] Composer installed.${NC}"

# =============================================================================
# STEP 5: Install Asterisk 20
# =============================================================================
echo -e "\n${YELLOW}[5/8] Installing Asterisk 20...${NC}"

cd /usr/src

# Download Asterisk 20
if [ ! -f "asterisk-20-current.tar.gz" ]; then
    wget -q https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-20-current.tar.gz
fi

tar xzf asterisk-20-current.tar.gz
cd asterisk-20*/

# Install prerequisites
contrib/scripts/install_prereq install -y

# Configure with PJSIP and WebSocket support
./configure --with-pjproject-bundled --with-jansson-bundled

# Select modules
make menuselect.makeopts
menuselect/menuselect \
    --enable res_pjsip \
    --enable res_pjsip_transport_websocket \
    --enable res_pjsip_session \
    --enable res_pjsip_sdp_rtp \
    --enable res_pjsip_registrar \
    --enable res_pjsip_authenticator_digest \
    --enable res_pjsip_endpoint_identifier_user \
    --enable res_http_websocket \
    --enable app_mixmonitor \
    --enable codec_opus \
    --enable codec_g722 \
    --enable CORE-SOUNDS-EN-WAV \
    --enable CORE-SOUNDS-EN-ULAW \
    --enable MOH-OPSOUND-WAV \
    --disable chan_sip \
    menuselect.makeopts

# Build and install
make -j$(nproc)
make install
make samples
make config
ldconfig

# Create asterisk user
adduser --system --group --home /var/lib/asterisk --no-create-home asterisk 2>/dev/null || true

# Set permissions
chown -R asterisk:asterisk /etc/asterisk
chown -R asterisk:asterisk /var/lib/asterisk
chown -R asterisk:asterisk /var/log/asterisk
chown -R asterisk:asterisk /var/spool/asterisk
chown -R asterisk:asterisk /var/run/asterisk 2>/dev/null || true

# Create recording directory
mkdir -p ${ASTERISK_RECORDING_DIR}
chown -R asterisk:asterisk ${ASTERISK_RECORDING_DIR}
chmod 775 ${ASTERISK_RECORDING_DIR}

echo -e "${GREEN}[5/8] Asterisk 20 installed.${NC}"

# =============================================================================
# STEP 6: Configure Asterisk
# =============================================================================
echo -e "\n${YELLOW}[6/8] Configuring Asterisk...${NC}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASTERISK_CONF_DIR="${SCRIPT_DIR}/../asterisk"

# Backup original configs
cp /etc/asterisk/pjsip.conf /etc/asterisk/pjsip.conf.bak 2>/dev/null || true
cp /etc/asterisk/extensions.conf /etc/asterisk/extensions.conf.bak 2>/dev/null || true
cp /etc/asterisk/http.conf /etc/asterisk/http.conf.bak 2>/dev/null || true

# Copy our configurations
cp ${ASTERISK_CONF_DIR}/pjsip.conf /etc/asterisk/pjsip.conf
cp ${ASTERISK_CONF_DIR}/extensions.conf /etc/asterisk/extensions.conf
cp ${ASTERISK_CONF_DIR}/http.conf /etc/asterisk/http.conf
cp ${ASTERISK_CONF_DIR}/modules.conf /etc/asterisk/modules.conf
cp ${ASTERISK_CONF_DIR}/rtp.conf /etc/asterisk/rtp.conf
cp ${ASTERISK_CONF_DIR}/manager.conf /etc/asterisk/manager.conf

# Update asterisk.conf to run as asterisk user
sed -i 's/;runuser = asterisk/runuser = asterisk/' /etc/asterisk/asterisk.conf
sed -i 's/;rungroup = asterisk/rungroup = asterisk/' /etc/asterisk/asterisk.conf

# Set permissions
chown -R asterisk:asterisk /etc/asterisk

# Enable and start Asterisk
systemctl enable asterisk
systemctl restart asterisk

echo -e "${GREEN}[6/8] Asterisk configured and started.${NC}"

# =============================================================================
# STEP 7: Install and Configure Laravel
# =============================================================================
echo -e "\n${YELLOW}[7/8] Setting up Laravel application...${NC}"

# Create Laravel project
mkdir -p /var/www
cd /var/www
composer create-project laravel/laravel call-center --prefer-dist --no-interaction

cd ${LARAVEL_DIR}

# Install Sanctum
composer require laravel/sanctum --no-interaction

# Configure .env
cat > ${LARAVEL_DIR}/.env <<EOF
APP_NAME="Call Center"
APP_ENV=production
APP_KEY=
APP_DEBUG=true
APP_URL=http://${SERVER_IP}:8000

LOG_CHANNEL=stack
LOG_LEVEL=debug

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=${MYSQL_DB}
DB_USERNAME=${MYSQL_USER}
DB_PASSWORD=${MYSQL_PASSWORD}

BROADCAST_DRIVER=log
CACHE_DRIVER=file
FILESYSTEM_DISK=public
QUEUE_CONNECTION=sync
SESSION_DRIVER=file
SESSION_LIFETIME=120

SANCTUM_STATEFUL_DOMAINS=${SERVER_IP}:8000
EOF

# Generate app key
php artisan key:generate --force

# Copy our application files
LARAVEL_SRC="${SCRIPT_DIR}/../laravel"

# Models
cp ${LARAVEL_SRC}/app/Models/User.php ${LARAVEL_DIR}/app/Models/User.php
cp ${LARAVEL_SRC}/app/Models/Shipment.php ${LARAVEL_DIR}/app/Models/Shipment.php
cp ${LARAVEL_SRC}/app/Models/CallRecording.php ${LARAVEL_DIR}/app/Models/CallRecording.php

# Controllers
cp ${LARAVEL_SRC}/app/Http/Controllers/AuthController.php ${LARAVEL_DIR}/app/Http/Controllers/AuthController.php
cp ${LARAVEL_SRC}/app/Http/Controllers/ShipmentController.php ${LARAVEL_DIR}/app/Http/Controllers/ShipmentController.php
cp ${LARAVEL_SRC}/app/Http/Controllers/RecordingController.php ${LARAVEL_DIR}/app/Http/Controllers/RecordingController.php
cp ${LARAVEL_SRC}/app/Http/Controllers/DashboardController.php ${LARAVEL_DIR}/app/Http/Controllers/DashboardController.php

# Routes
cp ${LARAVEL_SRC}/routes/api.php ${LARAVEL_DIR}/routes/api.php
cp ${LARAVEL_SRC}/routes/web.php ${LARAVEL_DIR}/routes/web.php

# Migrations (remove defaults first)
rm -f ${LARAVEL_DIR}/database/migrations/*create_users_table*
rm -f ${LARAVEL_DIR}/database/migrations/*create_password_reset*
rm -f ${LARAVEL_DIR}/database/migrations/*create_failed_jobs*
rm -f ${LARAVEL_DIR}/database/migrations/*create_personal_access*
rm -f ${LARAVEL_DIR}/database/migrations/*create_sessions*
rm -f ${LARAVEL_DIR}/database/migrations/*create_cache*
rm -f ${LARAVEL_DIR}/database/migrations/*create_jobs*

cp ${LARAVEL_SRC}/database/migrations/*.php ${LARAVEL_DIR}/database/migrations/

# Seeders
cp ${LARAVEL_SRC}/database/seeders/DatabaseSeeder.php ${LARAVEL_DIR}/database/seeders/DatabaseSeeder.php

# Views
cp ${LARAVEL_SRC}/resources/views/dashboard.blade.php ${LARAVEL_DIR}/resources/views/dashboard.blade.php

# Create storage link
php artisan storage:link 2>/dev/null || true

# Symlink Asterisk recordings to Laravel public storage
ln -sf ${ASTERISK_RECORDING_DIR} ${LARAVEL_DIR}/storage/app/public/asterisk-recordings

# Run migrations and seed
php artisan migrate --force
php artisan db:seed --force

# Set permissions
chown -R www-data:www-data ${LARAVEL_DIR}
chmod -R 775 ${LARAVEL_DIR}/storage
chmod -R 775 ${LARAVEL_DIR}/bootstrap/cache

# Allow www-data to read asterisk recordings
usermod -aG asterisk www-data 2>/dev/null || true
setfacl -R -m u:www-data:rx ${ASTERISK_RECORDING_DIR}
setfacl -R -d -m u:www-data:rx ${ASTERISK_RECORDING_DIR}

echo -e "${GREEN}[7/8] Laravel application installed and configured.${NC}"

# =============================================================================
# STEP 8: Setup Supervisor & Firewall
# =============================================================================
echo -e "\n${YELLOW}[8/8] Configuring Supervisor and Firewall...${NC}"

# Supervisor config for Laravel
cat > /etc/supervisor/conf.d/laravel.conf <<EOF
[program:laravel]
process_name=%(program_name)s
command=php artisan serve --host=0.0.0.0 --port=8000
directory=${LARAVEL_DIR}
autostart=true
autorestart=true
user=www-data
redirect_stderr=true
stdout_logfile=/var/log/supervisor/laravel.log
EOF

supervisorctl reread
supervisorctl update
supervisorctl start laravel

# Configure UFW Firewall
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp        # SSH
ufw allow 80/tcp        # HTTP
ufw allow 443/tcp       # HTTPS
ufw allow 5060/udp      # SIP UDP
ufw allow 5060/tcp      # SIP TCP
ufw allow 8088/tcp      # Asterisk HTTP/WebSocket
ufw allow 8089/tcp      # Asterisk HTTPS/WSS
ufw allow 8000/tcp      # Laravel
ufw allow 5038/tcp      # AMI (only if needed)
ufw allow 10000:20000/udp  # RTP media
ufw --force enable

echo -e "${GREEN}[8/8] Supervisor and Firewall configured.${NC}"

# =============================================================================
# FINAL SUMMARY
# =============================================================================
echo -e "\n${BLUE}=============================================${NC}"
echo -e "${GREEN}  SETUP COMPLETE!${NC}"
echo -e "${BLUE}=============================================${NC}"
echo -e ""
echo -e "${YELLOW}Server IP:${NC} ${SERVER_IP}"
echo -e ""
echo -e "${YELLOW}Asterisk PBX:${NC}"
echo -e "  SIP/WebSocket: ws://${SERVER_IP}:8088/ws"
echo -e "  Agents: agent1 - agent25"
echo -e "  Passwords: AgentPass[N]2024"
echo -e "  Recordings: ${ASTERISK_RECORDING_DIR}"
echo -e ""
echo -e "${YELLOW}Laravel API:${NC}"
echo -e "  URL: http://${SERVER_IP}:8000"
echo -e "  Dashboard: http://${SERVER_IP}:8000"
echo -e "  API Login: POST http://${SERVER_IP}:8000/api/login"
echo -e "  API Shipments: GET http://${SERVER_IP}:8000/api/shipments"
echo -e ""
echo -e "${YELLOW}MySQL:${NC}"
echo -e "  Database: ${MYSQL_DB}"
echo -e "  User: ${MYSQL_USER}"
echo -e "  Password: ${MYSQL_PASSWORD}"
echo -e ""
echo -e "${YELLOW}Sample Login:${NC}"
echo -e "  Email: agent1@demo.com"
echo -e "  Password: password123"
echo -e "  SIP Account: agent1"
echo -e "  SIP Password: AgentPass12024"
echo -e ""
echo -e "${YELLOW}Flutter App Config:${NC}"
echo -e "  Update API base URL in: lib/services/api_service.dart"
echo -e "  Change YOUR_VPS_IP to: ${SERVER_IP}"
echo -e ""
echo -e "${BLUE}=============================================${NC}"
echo -e "${GREEN}  All services are running!${NC}"
echo -e "${BLUE}=============================================${NC}"
