#!/bin/bash
set -u

BUNDLE_ID="com.yora.app"
UNINSTALLER_PATH="${1:-}"

bundle_id_of() {
  /usr/bin/defaults read "$1/Contents/Info" CFBundleIdentifier 2>/dev/null
}

CUSTOM_CACHE="$(/usr/bin/defaults read "$BUNDLE_ID" flutter.customCacheDir 2>/dev/null || true)"
if [ -n "$CUSTOM_CACHE" ] && [ -d "$CUSTOM_CACHE/yora_online" ]; then
  rm -rf "$CUSTOM_CACHE/yora_online"
fi
rm -rf "$HOME/Library/Caches/Yora"

rm -rf "$HOME/Library/Caches/$BUNDLE_ID" \
  "$HOME/Library/HTTPStorages/$BUNDLE_ID" \
  "$HOME/Library/HTTPStorages/$BUNDLE_ID.binarycookies" \
  "$HOME/Library/Saved Application State/$BUNDLE_ID.savedState" \
  "$HOME/Library/WebKit/$BUNDLE_ID"

/bin/launchctl bootout "gui/$(id -u)/$BUNDLE_ID" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$BUNDLE_ID.plist"

CANDIDATES=()
case "$UNINSTALLER_PATH" in
  */Contents/Resources/*)
    CANDIDATES+=("${UNINSTALLER_PATH%%/Contents/Resources/*}")
    ;;
  ?*)
    CANDIDATES+=("$(dirname "$UNINSTALLER_PATH")/Yora.app")
    ;;
esac
CANDIDATES+=("/Applications/Yora.app" "$HOME/Applications/Yora.app")

for app in "${CANDIDATES[@]}"; do
  if [ -d "$app" ] && [ "$(bundle_id_of "$app")" = "$BUNDLE_ID" ]; then
    rm -rf "$app"
  fi
done

exit 0
