#!/bin/bash

# M17 Hotspot Installation Script for Raspberry Pi with CC1220 HAT
# Must be run on a fresh install of Raspberry Pi OS Bookworm

# ---------------- CONFIGURATION ----------------
REQUIRED_PACKAGES="git libzmq3-dev cmake libgpiod-dev nginx php-fpm stm32flash"
CONFIG_FILE="/boot/firmware/config.txt"
M17_HOME="/opt/m17"
M17_USER="m17"
# ------------------------------------------------

set -e

# 1. Must be run as root
if [[ $EUID -ne 0 ]]; then
    echo "❌ This script must be run as root. Please use sudo."
    exit 1
fi

# 2. Check for Raspberry Pi OS Bookworm
if ! grep -q "bookworm" /etc/os-release; then
    echo "❌ This script is intended for Raspberry Pi OS Bookworm only."
    exit 1
fi

# 3. Fresh install warning
echo "⚠️  WARNING: This script is intended to be run on a fresh Raspberry Pi OS installation."
read -rp "❓ Do you wish to proceed? (Y/n): " CONFIRM
if [[ "$CONFIRM" != "Y" ]]; then
    echo "❌ Aborting setup."
    exit 1
fi
# 9. Install dashboard
sudo -u "$M17_USER" bash <<EOF
cd "$M17_HOME"
echo "📥 Cloning rpi-dashboard..."
git clone https://github.com/M17-Project/rpi-dashboard
EOF

# 10. Configure Nginx and PHP
echo "🛠️  Configuring nginx and PHP..."
systemctl enable nginx
systemctl enable php8.2-fpm || true  # may differ slightly based on system
NGINX_DEFAULT="/etc/nginx/sites-enabled/default"

# Enable PHP support and set root
sed -i 's/index index.html/index index.php index.html/' "$NGINX_DEFAULT"

# Uncomment the entire PHP block
sed -i '/location ~ \\.php\$ {/s/^#//' "$NGINX_DEFAULT"
sed -i '/fastcgi_pass unix:\/run\/php\/php.*\.sock;/s/^#//' "$NGINX_DEFAULT"
sed -i '/include snippets\/fastcgi-php.conf;/s/^#//' "$NGINX_DEFAULT"
sed -i '/}/s/^#//' "$NGINX_DEFAULT"

# Set correct web root
sed -i "s|root /var/www/html;|root $M17_HOME/rpi-dashboard;|" "$NGINX_DEFAULT"

echo "🔁 Restarting nginx..."
systemctl restart nginx

# 11. Final Instructions
echo -e "\n✅ Setup complete!"
echo "➡️  Please manually configure your node in:"
echo "   $M17_HOME/etc/rpi-interface.cfg"
echo "   - Set your call sign, frequency, and other settings."
echo "   - Set log file to: $M17_HOME/rpi-dashboard/files/log.txt"

# 12. Set placeholder MOTD
#echo "foo bar" > /etc/motd

echo "🎉 All done! You can now begin using your M17 hotspot!"
