#!/bin/bash
# =============================================================
# DEPLOY SCRIPT - Run this on VPS after git pull
# Usage: cd /root/Dialler && ./scripts/deploy.sh
# =============================================================

set -e
echo "=========================================="
echo "  Deploying Call Center System..."
echo "=========================================="

PROJECT_DIR="/root/Dialler"
LARAVEL_DIR="/var/www/call-center"
ASTERISK_DIR="/etc/asterisk"

# ── 1. Update Asterisk configs ──
echo ""
echo "[1/5] Updating Asterisk configs..."
cp -f $PROJECT_DIR/asterisk/pjsip.conf $ASTERISK_DIR/pjsip.conf
cp -f $PROJECT_DIR/asterisk/extensions.conf $ASTERISK_DIR/extensions.conf
cp -f $PROJECT_DIR/asterisk/http.conf $ASTERISK_DIR/http.conf
cp -f $PROJECT_DIR/asterisk/modules.conf $ASTERISK_DIR/modules.conf
cp -f $PROJECT_DIR/asterisk/rtp.conf $ASTERISK_DIR/rtp.conf
cp -f $PROJECT_DIR/asterisk/manager.conf $ASTERISK_DIR/manager.conf
chown -R asterisk:asterisk $ASTERISK_DIR/
asterisk -rx "core reload" 2>/dev/null || true
echo "  ✓ Asterisk configs updated and reloaded"

# ── 2. Update Laravel files ──
echo ""
echo "[2/5] Updating Laravel files..."
# Copy app files
cp -rf $PROJECT_DIR/laravel/app/* $LARAVEL_DIR/app/ 2>/dev/null || true
cp -rf $PROJECT_DIR/laravel/routes/* $LARAVEL_DIR/routes/ 2>/dev/null || true
cp -rf $PROJECT_DIR/laravel/resources/* $LARAVEL_DIR/resources/ 2>/dev/null || true
cp -rf $PROJECT_DIR/laravel/database/* $LARAVEL_DIR/database/ 2>/dev/null || true
cp -rf $PROJECT_DIR/laravel/config/* $LARAVEL_DIR/config/ 2>/dev/null || true
cp -rf $PROJECT_DIR/laravel/public/* $LARAVEL_DIR/public/ 2>/dev/null || true
chown -R www-data:www-data $LARAVEL_DIR/
echo "  ✓ Laravel files updated"

# ── 3. Clear Laravel cache ──
echo ""
echo "[3/5] Clearing Laravel cache..."
cd $LARAVEL_DIR
php artisan view:clear 2>/dev/null || true
php artisan route:clear 2>/dev/null || true
php artisan config:clear 2>/dev/null || true
echo "  ✓ Cache cleared"

# ── 4. Run migrations ──
echo ""
echo "[4/5] Running migrations..."
php artisan migrate --force 2>/dev/null || true
echo "  ✓ Migrations done"

# ── 5. Restart services ──
echo ""
echo "[5/5] Restarting services..."
supervisorctl restart laravel 2>/dev/null || true
systemctl restart asterisk 2>/dev/null || true
echo "  ✓ Services restarted"

echo ""
echo "=========================================="
echo "  ✓ Deployment complete!"
echo "  Dashboard: http://$(hostname -I | awk '{print $1}'):8000"
echo "=========================================="
