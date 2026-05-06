#!/usr/bin/env bash
set -e

echo "[Storymaker] Preparando sistema..."

# -----------------------------------------
# 👤 Usuario
# -----------------------------------------
if id "story" &>/dev/null; then
    echo "[Storymaker] Usuario story ya existe"
else
    useradd -m -s /bin/bash story
    echo "story:atrapa" | chpasswd
    usermod -aG sudo story
fi

# -----------------------------------------
# 🔐 SSH (en Raspberry se activa creando archivo)
# -----------------------------------------
touch /boot/firmware/ssh

# -----------------------------------------
# 🧠 SCRIPT DE PRIMER ARRANQUE
# -----------------------------------------
cat > /usr/local/bin/storymaker-firstboot.sh <<'EOF'
#!/bin/bash

echo "[Storymaker] Primer arranque..."

apt-get update
apt-get install -y hostapd dnsmasq lighttpd php

# -----------------------------------------
# 📶 hostapd (AP)
# -----------------------------------------
cat > /etc/hostapd/hostapd.conf <<EOL
interface=wlan0
driver=nl80211
ssid=storymaker
hw_mode=g
channel=7
wmm_enabled=0
auth_algs=1
ignore_broadcast_ssid=0
EOL

sed -i 's|#DAEMON_CONF=""|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd

# -----------------------------------------
# 🌐 dnsmasq
# -----------------------------------------
mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig

cat > /etc/dnsmasq.conf <<EOL
interface=wlan0
dhcp-range=192.168.4.10,192.168.4.50,255.255.255.0,24h
address=/#/192.168.4.1
EOL

# -----------------------------------------
# 📡 IP fija
# -----------------------------------------
cat >> /etc/dhcpcd.conf <<EOL

interface wlan0
static ip_address=192.168.4.1/24
nohook wpa_supplicant
EOL

# -----------------------------------------
# 🌍 PORTAL
# -----------------------------------------
mkdir -p /var/www/html

cat > /var/www/html/index.php <<'EOL'
<!DOCTYPE html>
<html>
<body>
<h1>Storymaker Setup</h1>
<form method="post" action="save.php">
SSID:<br><input name="ssid"><br>
Password:<br><input type="password" name="psk"><br>

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
EOL

cat > /var/www/html/save.php <<'EOL'
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

exec("sudo reboot");
?>
EOL

# permisos PHP
echo "www-data ALL=(ALL) NOPASSWD: /sbin/reboot" > /etc/sudoers.d/storymaker
chmod 0440 /etc/sudoers.d/storymaker

# -----------------------------------------
# 🔁 SCRIPT DE MODO RED
# -----------------------------------------
cat > /usr/local/bin/storymaker-net.sh <<'EOL'
#!/bin/bash

if grep -q "ssid=" /etc/wpa_supplicant/wpa_supplicant.conf 2>/dev/null; then
    systemctl stop hostapd
    systemctl stop dnsmasq
else
    systemctl start hostapd
    systemctl start dnsmasq
fi
EOL

chmod +x /usr/local/bin/storymaker-net.sh

cat > /etc/systemd/system/storymaker-net.service <<EOL
[Unit]
Description=Storymaker Network Mode
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/storymaker-net.sh

[Install]
WantedBy=multi-user.target
EOL

systemctl enable hostapd
systemctl enable dnsmasq
systemctl enable lighttpd
systemctl enable storymaker-net.service

# -----------------------------------------
# ❗ Ejecutar solo una vez
# -----------------------------------------
systemctl disable storymaker-firstboot.service

echo "[Storymaker] Configuración completada"
EOF

chmod +x /usr/local/bin/storymaker-firstboot.sh

# -----------------------------------------
# ⚙️ Servicio firstboot
# -----------------------------------------
cat > /etc/systemd/system/storymaker-firstboot.service <<EOF
[Unit]
Description=Storymaker First Boot
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/storymaker-firstboot.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

systemctl enable storymaker-firstboot.service

echo "[Storymaker] ✅ Setup preparado"
``
