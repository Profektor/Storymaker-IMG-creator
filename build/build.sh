#!/usr/bin/env bash
set -e

echo "=== Storymaker Image Build ==="

WORKDIR="$HOME/storymaker-work"
BASE_IMG="$WORKDIR/base.img"
OUTPUT_IMG="$WORKDIR/storymaker-v0.1.img"

# Detectar SDM (ruta absoluta para sudo)
if command -v sdm &>/dev/null; then
  SDM="$(command -v sdm)"
elif [ -f "$HOME/sdm/sdm" ]; then
  SDM="$HOME/sdm/sdm"
else
  echo "❌ SDM no encontrado"
  exit 1
fi

if [ ! -f "$BASE_IMG" ]; then
  echo "❌ No existe base.img en $WORKDIR"
  exit 1
fi

echo "→ Copiando imagen base..."
cp "$BASE_IMG" "$OUTPUT_IMG"

echo "→ Personalizando imagen con SDM..."
sudo "$SDM" --customize "$OUTPUT_IMG" \
  --batch \
  --cscript "$(realpath "$PWD/setup.sh")" \
  --regen-ssh-host-keys

echo "✅ Imagen generada en: $OUTPUT_IMG"
