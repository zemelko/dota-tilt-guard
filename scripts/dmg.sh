#!/bin/bash
set -euo pipefail
SOURCE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-$SOURCE_ROOT/../Calm Chat.app}"
OUTPUT_ROOT="${2:-$SOURCE_ROOT/..}"
WORK_ROOT="${3:-$SOURCE_ROOT/.build/dmg}"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
case "$VERSION" in ''|*[!0-9.]*) echo 'Invalid version' >&2; exit 1 ;; esac
codesign --verify --deep --strict "$APP_PATH"
mkdir -p "$WORK_ROOT" "$OUTPUT_ROOT"
STAGE="$(mktemp -d "$WORK_ROOT/stage.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP_PATH" "$STAGE/Calm Chat.app"
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/Установка.txt" <<'INSTALL'
Calm Chat — установка

1. Заверши уже запущенный Calm Chat через его значок в строке меню → «Завершить».
2. Перетащи Calm Chat.app на папку Applications в этом окне.
3. Извлеки образ диска и открой Calm Chat из Applications (Программы).

Для текстового фильтра разреши приложение в Accessibility / Универсальный доступ.
Для голосового режима разреши микрофон. Нужны macOS 26+ и BlackHole 2ch.
На Mac, где создана эта сборка, BlackHole уже установлен.

Если Accessibility не подтверждается, повторно добавь Calm Chat именно из Applications.
Не запускай несколько версий одновременно.

Голосовая защита: выбери настоящий микрофон в Calm Chat, включи защиту;
в игре используй системный вход или BlackHole 2ch.
Ругательство временно отключает передачу на 3 секунды, распознавание работает локально.
INSTALL
hdiutil create -volname "Calm Chat $VERSION" -srcfolder "$STAGE" \
  -format UDZO -ov "$OUTPUT_ROOT/CalmChat-$VERSION.dmg"
hdiutil verify "$OUTPUT_ROOT/CalmChat-$VERSION.dmg"
printf 'Готово: %s/CalmChat-%s.dmg\n' "$OUTPUT_ROOT" "$VERSION"
