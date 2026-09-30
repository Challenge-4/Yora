#!/bin/sh
set -eu

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
DESKTOP_FILE="$DATA_HOME/applications/com.yora.app.desktop"

if [ ! -x "$APP_DIR/yora" ]; then
  echo "Erreur : lance ce script depuis le dossier de Yora (yora introuvable)." >&2
  exit 1
fi

library_cache() {
  ldconfig -p 2>/dev/null || /sbin/ldconfig -p 2>/dev/null || true
}

has_lib() {
  cache="$(library_cache)"
  for name in "$@"; do
    if printf '%s\n' "$cache" | grep -qF "$name "; then
      return 0
    fi
  done
  return 1
}

missing_components() {
  has_lib libgtk-3.so.0 || echo gtk
  has_lib libmpv.so.2 libmpv.so.1 libmpv.so || echo mpv
  has_lib libkeybinder-3.0.so.0 || echo keybinder
  has_lib libayatana-appindicator3.so.1 || echo indicator
  has_lib libGLESv2.so.2 || echo gles
}

package_manager() {
  for pm in apt-get dnf pacman zypper; do
    if command -v "$pm" >/dev/null 2>&1; then
      echo "$pm"
      return
    fi
  done
}

package_for() {
  case "$1:$2" in
    apt-get:gtk) echo libgtk-3-0 ;;
    apt-get:mpv) if apt-cache show libmpv2 >/dev/null 2>&1; then echo libmpv2; else echo libmpv1; fi ;;
    apt-get:keybinder) echo libkeybinder-3.0-0 ;;
    apt-get:indicator) echo libayatana-appindicator3-1 ;;
    apt-get:gles) echo libgles2 ;;
    dnf:gtk) echo gtk3 ;;
    dnf:mpv) echo mpv-libs ;;
    dnf:keybinder) echo keybinder3 ;;
    dnf:indicator) echo libayatana-appindicator-gtk3 ;;
    dnf:gles) echo libglvnd-gles ;;
    pacman:gtk) echo gtk3 ;;
    pacman:mpv) echo mpv ;;
    pacman:keybinder) echo libkeybinder3 ;;
    pacman:indicator) echo libayatana-appindicator ;;
    pacman:gles) echo libglvnd ;;
    zypper:gtk) echo libgtk-3-0 ;;
    zypper:mpv) echo libmpv2 ;;
    zypper:keybinder) echo libkeybinder-3_0-0 ;;
    zypper:indicator) echo libayatana-appindicator3-1 ;;
    zypper:gles) echo libglvnd ;;
  esac
}

install_dependencies() {
  missing="$(missing_components)"
  [ -n "$missing" ] || return 0

  pm="$(package_manager)"
  if [ -z "$pm" ]; then
    echo "Bibliothèques manquantes : $(echo $missing). Installe-les avec le gestionnaire de paquets de ta distribution." >&2
    return 0
  fi

  packages=""
  for component in $missing; do
    packages="$packages $(package_for "$pm" "$component")"
  done

  if [ "$(id -u)" -eq 0 ]; then
    run_as_root=""
  elif command -v sudo >/dev/null 2>&1; then
    run_as_root="sudo"
  else
    echo "Bibliothèques manquantes :$packages. Installe-les en administrateur, puis relance ce script." >&2
    return 0
  fi

  echo "Installation des bibliothèques nécessaires :$packages"
  case "$pm" in
    apt-get)
      $run_as_root apt-get install -y $packages || { $run_as_root apt-get update && $run_as_root apt-get install -y $packages; } || true ;;
    dnf)
      $run_as_root dnf install -y $packages || true ;;
    pacman)
      $run_as_root pacman -S --needed --noconfirm $packages || true ;;
    zypper)
      $run_as_root zypper --non-interactive install $packages || true ;;
  esac

  still_missing="$(missing_components)"
  if [ -n "$still_missing" ]; then
    echo "Attention : certaines bibliothèques manquent encore ($(echo $still_missing)). Yora risque de ne pas démarrer." >&2
  fi
}

install_dependencies

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

if [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
  nohup "$APP_DIR/yora" >/dev/null 2>&1 &
fi
