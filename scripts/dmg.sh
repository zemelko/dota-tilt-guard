#!/bin/bash
set -euo pipefail
SOURCE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-$SOURCE_ROOT/../Dota Tilt Guard.app}"
OUTPUT_ROOT="${2:-$SOURCE_ROOT/..}"
WORK_ROOT="${3:-$SOURCE_ROOT/.build/dmg}"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
case "$VERSION" in ''|*[!0-9.]*) echo 'Invalid version' >&2; exit 1 ;; esac
codesign --verify --deep --strict "$APP_PATH"
mkdir -p "$WORK_ROOT" "$OUTPUT_ROOT"
STAGE="$(mktemp -d "$WORK_ROOT/stage.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP_PATH" "$STAGE/Dota Tilt Guard.app"
ln -s /Applications "$STAGE/Applications"
cp "$SOURCE_ROOT/README.ru.md" "$STAGE/Установка — русский.txt"
cp "$SOURCE_ROOT/README.md" "$STAGE/Installation — English.txt"
cp "$SOURCE_ROOT/COPYRIGHT.md" "$STAGE/COPYRIGHT.txt"
mkdir -p "$STAGE/Voice setup"
cat > "$STAGE/Voice setup/BlackHole 2ch — official installer.webloc" <<'LINK'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>URL</key><string>https://existential.audio/downloads/BlackHole2ch-0.7.1.pkg</string></dict></plist>
LINK
cat > "$STAGE/Voice setup/Read me.txt" <<'SETUP'
BlackHole 2ch is installed separately from its official developer.
Open the installer link in this folder, install it, then restart your Mac.
Already installed? Skip this step.
For Apple speech assets, open Dota Tilt Guard → gear button → Download language via macOS.
The first download needs internet; recognition runs locally afterward.
BlackHole: https://github.com/ExistentialAudio/BlackHole

BlackHole 2ch устанавливается отдельно с официального сайта разработчика.
Открой ссылку на установщик в этой папке, установи его и перезагрузи Mac.
Если BlackHole уже установлен, пропусти этот шаг.
Для языковых данных Apple: Dota Tilt Guard → шестерёнка → «Загрузить язык через macOS».
При первой загрузке нужен интернет; распознавание затем работает локально.
SETUP
hdiutil create -volname "Dota Tilt Guard $VERSION" -srcfolder "$STAGE" \
  -format UDZO -ov "$OUTPUT_ROOT/DotaTiltGuard-$VERSION.dmg"
hdiutil verify "$OUTPUT_ROOT/DotaTiltGuard-$VERSION.dmg"
(cd "$OUTPUT_ROOT" && shasum -a 256 "DotaTiltGuard-$VERSION.dmg" > "DotaTiltGuard-$VERSION.dmg.sha256")
printf 'Готово: %s/DotaTiltGuard-%s.dmg\n' "$OUTPUT_ROOT" "$VERSION"
