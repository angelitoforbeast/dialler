#!/bin/bash
# Quick fix script for common permission issues

ASTERISK_RECORDING_DIR="/var/spool/asterisk/recording"
LARAVEL_DIR="/var/www/call-center"

echo "Fixing Asterisk permissions..."
chown -R asterisk:asterisk /etc/asterisk
chown -R asterisk:asterisk /var/lib/asterisk
chown -R asterisk:asterisk /var/log/asterisk
chown -R asterisk:asterisk /var/spool/asterisk
mkdir -p ${ASTERISK_RECORDING_DIR}
chown -R asterisk:asterisk ${ASTERISK_RECORDING_DIR}
chmod 775 ${ASTERISK_RECORDING_DIR}

echo "Fixing Laravel permissions..."
chown -R www-data:www-data ${LARAVEL_DIR}
chmod -R 775 ${LARAVEL_DIR}/storage
chmod -R 775 ${LARAVEL_DIR}/bootstrap/cache

echo "Setting ACL for recording access..."
setfacl -R -m u:www-data:rx ${ASTERISK_RECORDING_DIR}
setfacl -R -d -m u:www-data:rx ${ASTERISK_RECORDING_DIR}

echo "Restarting services..."
systemctl restart asterisk
supervisorctl restart laravel

echo "Done! All permissions fixed."
