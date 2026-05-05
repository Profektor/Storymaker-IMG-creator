#!/usr/bin/env bash
set -e

echo "[Storymaker] Configurando sistema..."

# Crear usuario (seguro)
if id "story" &>/dev/null; then
    echo "[Storymaker] Usuario story ya existe"
else
    useradd -m -s /bin/bash story
    echo "story:atrapa" | chpasswd
    usermod -aG sudo story
    echo "[Storymaker] Usuario story creado"
fi

# Activar SSH
systemctl enable ssh || true

# Configurar país wifi
if command -v raspi-config &>/dev/null; then
    raspi-config nonint do_wifi_country ES || true
fi

echo "[Storymaker] Configuración terminada."
