#!/bin/sh
set -u

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

QUESTION="Désinstaller Yora ?

L'application et son cache seront supprimés. Tes playlists, tes réglages et tes MP3 téléchargés sont conservés : une réinstallation retrouvera tout."

confirm() {
  if [ -t 0 ]; then
    printf '%s\n\nContinuer ? [o/N] ' "$QUESTION"
    read -r answer
    case "$answer" in o|O|oui|Oui|y|Y|yes) return 0 ;; *) return 1 ;; esac
  elif command -v zenity >/dev/null 2>&1; then
    zenity --question --title="Désinstaller Yora" --text="$QUESTION" --ok-label="Désinstaller" --cancel-label="Annuler" 2>/dev/null
  elif command -v kdialog >/dev/null 2>&1; then
    kdialog --title "Désinstaller Yora" --warningcontinuecancel "$QUESTION" 2>/dev/null
  else
    return 0
  fi
}

notify_done() {
  if [ -t 1 ]; then
    echo "Yora a été désinstallé."
  elif command -v zenity >/dev/null 2>&1; then
    zenity --info --title="Désinstaller Yora" --text="Yora a été désinstallé." 2>/dev/null || true
  elif command -v kdialog >/dev/null 2>&1; then
    kdialog --title "Désinstaller Yora" --msgbox "Yora a été désinstallé." 2>/dev/null || true
  fi
}

confirm || exit 0

if command -v pkill >/dev/null 2>&1; then
  pkill -x yora 2>/dev/null && sleep 2
fi

for prefs in "$DATA_HOME/com.yora.app/shared_preferences.json" "$DATA_HOME/yora/shared_preferences.json"; do
  [ -f "$prefs" ] || continue
  custom_cache=""
  if command -v python3 >/dev/null 2>&1; then
    custom_cache="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8")).get("flutter.customCacheDir") or "")' "$prefs" 2>/dev/null || true)"
  fi
  if [ -n "$custom_cache" ] && [ -d "$custom_cache/yora_online" ]; then
    rm -rf "$custom_cache/yora_online"
  fi
done

rm -rf "$CACHE_HOME/Yora" "$CACHE_HOME/com.yora.app" "$CACHE_HOME/yora"
rm -f "$CONFIG_HOME/autostart/Yora.desktop"
rm -f "$DATA_HOME/applications/com.yora.app.desktop"
update-desktop-database "$DATA_HOME/applications" >/dev/null 2>&1 || true

if [ -x "$APP_DIR/yora" ] && [ -d "$APP_DIR/data/flutter_assets" ]; then
  rm -rf "$APP_DIR"
fi

notify_done
exit 0
