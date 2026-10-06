#!/bin/bash
set -euo pipefail
SOURCE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-$SOURCE_ROOT/../Dota Tilt Guard.app}"
BUILD_ROOT="${2:-$SOURCE_ROOT/.build}"
case "$APP_PATH" in /*.app) ;; *) echo 'Укажи абсолютный путь к .app' >&2; exit 1 ;; esac
mkdir -p "$BUILD_ROOT/module-cache" "$BUILD_ROOT/icons/DotaTiltGuard.iconset"
export CLANG_MODULE_CACHE_PATH="$BUILD_ROOT/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$BUILD_ROOT/module-cache"
swift build --package-path "$SOURCE_ROOT" --scratch-path "$BUILD_ROOT" --disable-sandbox \
  --cache-path "$BUILD_ROOT/cache" --config-path "$BUILD_ROOT/config" --security-path "$BUILD_ROOT/security" \
  -c release -debug-info-format none
BIN_PATH="$(swift build --package-path "$SOURCE_ROOT" --scratch-path "$BUILD_ROOT" -c release --show-bin-path)"
STAGING_ROOT="$(mktemp -d "$BUILD_ROOT/app.XXXXXX")"
trap 'rm -rf "$STAGING_ROOT"' EXIT
STAGED_APP="$STAGING_ROOT/Dota Tilt Guard.app"
mkdir -p "$STAGED_APP/Contents/MacOS" "$STAGED_APP/Contents/Resources"
cp "$BIN_PATH/CalmChat" "$STAGED_APP/Contents/MacOS/DotaTiltGuard"
if [ -f "$SOURCE_ROOT/Resources/DotaTiltGuard.icns" ]; then
  cp "$SOURCE_ROOT/Resources/DotaTiltGuard.icns" "$STAGED_APP/Contents/Resources/DotaTiltGuard.icns"
else
swift -module-cache-path "$CLANG_MODULE_CACHE_PATH" "$SOURCE_ROOT/scripts/icon.swift" "$BUILD_ROOT/icons/icon.png"
for SIZE in 16 32 128 256 512; do
  sips -z "$SIZE" "$SIZE" "$BUILD_ROOT/icons/icon.png" --out "$BUILD_ROOT/icons/DotaTiltGuard.iconset/icon_${SIZE}x${SIZE}.png" >/dev/null
  DOUBLE=$((SIZE * 2))
  sips -z "$DOUBLE" "$DOUBLE" "$BUILD_ROOT/icons/icon.png" --out "$BUILD_ROOT/icons/DotaTiltGuard.iconset/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
if [ -f "$APP_PATH/Contents/Resources/DotaTiltGuard.icns" ]; then
  cp "$APP_PATH/Contents/Resources/DotaTiltGuard.icns" "$STAGED_APP/Contents/Resources/DotaTiltGuard.icns"
else
  iconutil -c icns "$BUILD_ROOT/icons/DotaTiltGuard.iconset" -o "$STAGED_APP/Contents/Resources/DotaTiltGuard.icns"
fi
fi
cat > "$STAGED_APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>en</string><string>ru</string></array>
<key>CFBundleName</key><string>Dota Tilt Guard</string>
<key>CFBundleDisplayName</key><string>Dota Tilt Guard</string>
<key>CFBundleIdentifier</key><string>com.zemelko.dotatiltguard</string>
<key>CFBundleExecutable</key><string>DotaTiltGuard</string>
<key>CFBundleIconFile</key><string>DotaTiltGuard</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.5.1</string>
<key>CFBundleVersion</key><string>8</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>LSMultipleInstancesProhibited</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSMicrophoneUsageDescription</key><string>Локально распознавать твою речь и временно отключать передачу голоса при ругательствах.</string>
<key>NSSpeechRecognitionUsageDescription</key><string>Распознавать речь только на этом Mac для голосового фильтра.</string>
<key>NSAccessibilityUsageDescription</key><string>Проверять ввод только в Dota 2 и блокировать Enter при найденных оскорблениях.</string>
</dict></plist>
PLIST
cp -R "$SOURCE_ROOT/Resources/ru.lproj" "$SOURCE_ROOT/Resources/en.lproj" "$STAGED_APP/Contents/Resources/"
codesign --force --sign - "$STAGED_APP"
# Replace bundle contents so an upgrade cannot retain the old model or runtime.
mkdir -p "$APP_PATH"
rm -rf "$APP_PATH/Contents"
mv "$STAGED_APP/Contents" "$APP_PATH/Contents"
printf 'Готово: %s\n' "$APP_PATH"
