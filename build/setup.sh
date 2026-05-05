#!/usr/bin/env bash
set -e

echo "[Storymaker] Configuración inicial..."

# -----------------------------------------
# 👤 Usuario
# -----------------------------------------
if id "story" &>/dev/null; then
    echo "[Storymaker] Usuario story ya existe"
else
    useradd -m -s /bin/bash story
    echo "story:atrapa" | chpasswd
    usermod -aG sudo story
    echo "[Storymaker] Usuario story creado"
fi

# -----------------------------------------
# 🔐 SSH
# -----------------------------------------
systemctl enable ssh || true

# -----------------------------------------
# 📦 Paquetes necesarios
# -----------------------------------------
apt-get update
apt-get install -y hostapd dnsmasq lighttpd php

# -----------------------------------------
# 📶 hostapd (WiFi AP)
# -----------------------------------------
cat > /etc/hostapd/hostapd.conf <<EOF
interface=wlan0
driver=nl80211
ssid=storymaker
hw_mode=g
channel=7
wmm_enabled=0
auth_algs=1
ignore_broadcast_ssid=0
EOF

sed -i 's|#DAEMON_CONF=""|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd

# -----------------------------------------
# 🌐 dnsmasq
# -----------------------------------------
mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig

cat > /etc/dnsmasq.conf <<EOF
interface=wlan0
dhcp-range=192.168.4.10,192.168.4.50,255.255.255.0,24h
address=/#/192.168.4.1
EOF

# -----------------------------------------
# 📡 IP fija
# -----------------------------------------
cat >> /etc/dhcpcd.conf <<EOF

interface wlan0
    static ip_address=192.168.4.1/24
EOF

# -----------------------------------------
# 🧠 Script de decisión (AP vs cliente)
# -----------------------------------------
cat > /usr/local/bin/storymaker-net.sh <<'EOF'
#!/bin/bash

WPA_CONF="/etc/wpa_supplicant/wpa_supplicant.conf"

if grep -q "ssid=" "$WPA_CONF" 2>/dev/null; then
    systemctl stop hostapd
    systemctl stop dnsmasq
else
    systemctl start hostapd
    systemctl start dnsmasq
fi
EOF

chmod +x /usr/local/bin/storymaker-net.sh

# -----------------------------------------
# ⚙️ Servicio systemd
# -----------------------------------------
cat > /etc/systemd/system/storymaker-net.service <<EOF
[Unit]
Description=Storymaker Network Mode
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/storymaker-net.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

systemctl enable storymaker-net.service

# -----------------------------------------
# 🌍 Portal web
# -----------------------------------------
mkdir -p /var/www/html

cat > /var/www/html/index.php <<'EOF'
<!DOCTYPE html>
<html>
<head><title>Storymaker Setup</title></head>
<body>
<h1>Configurar WiFi</h1>

<form method="POST" action="save.php">
SSID:<br>
<input type="text" name="ssid"><br>

Password:<br>
<input type="password" name="psk"><br>

País:<br>
<select name="country">
<option value="ES">España</option>
<option value="FR">Francia</option>
<option value="DE">Alemania</option>
<option value="US">USA</option>
<option value="GB">UK</option>
</select><br><br>

<input type="submit" value="Guardar">
</form>
</body>
</html>
EOF

cat > /var/www/html/save.php <<'EOF'
<?php
$ssid = $_POST['ssid'];
$psk = $_POST['psk'];
$country = $_POST['country'];

$config = "country=$country
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid=\"$ssid\"
    psk=\"$psk\"
}";

file_put_contents("/etc/wpa_supplicant/wpa_supplicant.conf", $config);

exec("sudo systemctl disable hostapd");
exec("sudo systemctl disable dnsmasq");

echo "<h1>Guardado. Reiniciando...</h1>";

exec("sudo reboot");
?>
EOF

# -----------------------------------------
# 🔐 permisos sudo para web
# -----------------------------------------
echo "www-data ALL=(ALL) NOPASSWD: /sbin/reboot, /bin/systemctl" > /etc/sudoers.d/storymaker
chmod 0440 /etc/sudoers.d/storymaker

# -----------------------------------------
# 🔥 Activar servicios
# -----------------------------------------
systemctl unmask hostapd
systemctl enable hostapd
systemctl enable dnsmasq
systemctl enable lighttpd

echo "[Storymaker] ✅ Setup completado"
