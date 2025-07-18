#!/bin/bash

# M17 Hotspot Installation Script for Raspberry Pi with CC1220 HAT
# Must be run on a fresh install of Raspberry Pi OS Bookworm

# ---------------- CONFIGURATION ----------------
REQUIRED_PACKAGES="git libzmq3-dev cmake libgpiod-dev nginx php-fpm stm32flash"
CONFIG_FILE="/boot/firmware/config.txt"
M17_HOME="/opt/m17"
M17_USER="m17"
NGINX_DEFAULT="/etc/nginx/sites-enabled/default"
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

# 4. Update and check if reboot is needed
echo "📦 Updating system packages..."
apt update && apt -y dist-upgrade

if [ -f /var/run/reboot-required ]; then
    echo "🔁 A system reboot is required to continue."
    echo "ℹ️  Please reboot the system and rerun this script."
    exit 0
fi

# 5. Ensure UART config is correct
CONFIG_CHANGED=false

if ! grep -q "^dtoverlay=miniuart-bt" "$CONFIG_FILE"; then
    echo "dtoverlay=miniuart-bt" >> "$CONFIG_FILE"
    CONFIG_CHANGED=true
fi

if ! grep -q "^enable_uart=1" "$CONFIG_FILE"; then
    echo "enable_uart=1" >> "$CONFIG_FILE"
    CONFIG_CHANGED=true
fi

CMDLINE_FILE="/boot/firmware/cmdline.txt"
if grep -q "console=serial0,115200" "$CMDLINE_FILE"; then
    sed -i 's/console=serial0,115200 *//' "$CMDLINE_FILE"
    CONFIG_CHANGED=true
fi

if $CONFIG_CHANGED; then
    echo "⚙️  UART configuration updated. A reboot is required."
    echo "🔁 Please reboot the system and rerun this script."
    exit 0
fi

# 6. Install required packages
echo "📦 Installing required packages: $REQUIRED_PACKAGES"
apt install -y $REQUIRED_PACKAGES

# 7. Create M17 user
echo "👤 Creating user '$M17_USER' with home at $M17_HOME..."
useradd -m -d "$M17_HOME" -s /bin/bash "$M17_USER"
PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
echo "$M17_USER:$PASSWORD" | chpasswd
echo "User '$M17_USER' created with password: $PASSWORD"
echo "$M17_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$M17_USER"
mkdir -p "$M17_HOME"
chown -R "$M17_USER:$M17_USER" "$M17_HOME"

# Add m17 user to the groups dialout and gpio
usermod -aG dialout,gpio "$M17_USER"
echo "User '$M17_USER' has been added to the 'dialout' and 'gpio' groups."

# Use a subshell to switch to m17 user
sudo -u "$M17_USER" bash <<EOF
set -e
cd "$M17_HOME"
echo "📥 Cloning libm17..."
git clone https://github.com/M17-Project/libm17.git
cd libm17
cmake -DCMAKE_INSTALL_PREFIX=/usr -B build
cmake --build build
sudo cmake --install build

echo "📥 Cloning rpi-interface..."
cd "$M17_HOME"
git clone https://github.com/M17-Project/rpi-interface.git
cd rpi-interface
make
sudo make install
mkdir -p "$M17_HOME/etc"
cp default_cfg.txt "$M17_HOME/etc/rpi-interface.cfg"

echo "📥 Cloning CC1200_HAT-fw..."
cd "$M17_HOME"
git clone https://github.com/M17-Project/CC1200_HAT-fw.git
EOF

# 8. Optionally flash firmware
read -rp "💾 Do you want to flash the latest CC1200 firmware to the HAT? (Y/n): " FLASH_CONFIRM
if [[ "$FLASH_CONFIRM" == "Y" ]]; then
    echo "⚡ Flashing firmware to CC1200 HAT..."
    stm32flash -v -R -i "-532&-533&532,533,:-532,-533,533" -w "$M17_HOME/CC1200_HAT-fw/Release/CC1200_HAT-fw.bin" /dev/ttyAMA0
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
systemctl enable php8.2-fpm || true

sudo tee "$NGINX_DEFAULT" > /dev/null << 'EOF'
server {
        listen 80 default_server;
        listen [::]:80 default_server;

        root /opt/m17/rpi-dashboard;

	index index.php index.html index.htm;

        server_name _;

        location / {
                try_files $uri $uri/ =404;
        }

	location ~ \.php$ {
		include snippets/fastcgi-php.conf;
		fastcgi_pass unix:/var/run/php/php-fpm.sock;
        }
}
EOF

echo "🔁 Restarting nginx..."
systemctl restart nginx

# 13. Create a systemd service for rpi-interface

cat <<EOF | sudo tee /etc/systemd/system/rpi-interface.service
[Unit]
Description=Raspberry Pi Interface Service
After=network.target

[Service]
Type=simple
User=m17
ExecStart=/usr/local/bin/rpi-interface -c /opt/m17/etc/rpi-interface.cfg
Restart=on-failure
StandardOutput=journal
StandardError=journal
LogRateLimitIntervalSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable rpi-interface.service
systemctl start rpi-interface.service

# 12. Final Instructions
echo -e "\n✅ Setup complete!"
echo "➡️  Please manually configure your node in:"
echo "   $M17_HOME/etc/rpi-interface.cfg"
echo "   - Set your call sign, frequency, and other settings."
echo "   - Set log file to: $M17_HOME/rpi-dashboard/files/log.txt"

# 13. Set placeholder MOTD
#echo "foo bar" > /etc/motd

echo "🎉 All done! You can now begin using your M17 hotspot!"

