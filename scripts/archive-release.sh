#!/bin/bash
set -euo pipefail
SOURCE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-$SOURCE_ROOT/../Calm Chat.app}"
RELEASES_ROOT="${2:-$SOURCE_ROOT/../releases}"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
case "$VERSION" in ''|*[!0-9.]*) echo 'Invalid release version' >&2; exit 1 ;; esac
DEST="$RELEASES_ROOT/$VERSION"
if [ -e "$DEST" ]; then
  echo "Версия уже сохранена: $DEST. Архив не перезаписан." >&2
  exit 1
fi
codesign --verify --deep --strict "$APP_PATH"
mkdir -p "$RELEASES_ROOT"
STAGE="$(mktemp -d "$RELEASES_ROOT/.release.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP_PATH" "$STAGE/Calm Chat.app"
# Only reproducible source inputs, never caches or build products.
tar -czf "$STAGE/CalmChat-source.tar.gz" -C "$SOURCE_ROOT" \
  Package.swift Sources Tests scripts Resources README.md
(cd "$STAGE" && shasum -a 256 'Calm Chat.app/Contents/MacOS/CalmChat' CalmChat-source.tar.gz > SHA256.txt)
mv "$STAGE" "$DEST"
printf 'Сохранена версия %s: %s\n' "$VERSION" "$DEST"
