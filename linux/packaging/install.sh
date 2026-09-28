#!/bin/sh
set -eu

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
DESKTOP_FILE="$DATA_HOME/applications/com.yora.app.desktop"

if [ ! -x "$APP_DIR/yora" ]; then
  echo "Erreur : lance ce script depuis le dossier de Yora (yora introuvable)." >&2
  exit 1
fi

mkdir -p "$DATA_HOME/applications"
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=Yora
Comment=Lecteur de musique
Exec="$APP_DIR/yora"
Icon=$APP_DIR/data/flutter_assets/assets/app_icon.png
Terminal=false
Categories=AudioVideo;Audio;Player;
StartupWMClass=com.yora.app
Actions=Uninstall;

[Desktop Action Uninstall]
Name=Désinstaller Yora
Name[en]=Uninstall Yora
Exec="$APP_DIR/uninstall.sh"
EOF
chmod +x "$DESKTOP_FILE" "$APP_DIR/uninstall.sh"
update-desktop-database "$DATA_HOME/applications" >/dev/null 2>&1 || true

echo "Yora a été ajouté au menu des applications."
