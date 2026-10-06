#!/bin/bash
set -euo pipefail
SOURCE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_ROOT="${1:-$SOURCE_ROOT/.build/checks}"
mkdir -p "$TEST_ROOT/module-cache"
swiftc -D CALM_CHAT_STANDALONE_TESTS -module-cache-path "$TEST_ROOT/module-cache" \
  "$SOURCE_ROOT/Sources/CalmChatCore/Filter.swift" "$SOURCE_ROOT/Sources/CalmChatCore/ChatGuardState.swift" "$SOURCE_ROOT/Sources/CalmChatCore/VoiceGate.swift" "$SOURCE_ROOT/Tests/CalmChatCoreTests/FilterTests.swift" \
  -o "$TEST_ROOT/filter-tests"
"$TEST_ROOT/filter-tests"
swiftc -module-cache-path "$TEST_ROOT/module-cache" \
  "$SOURCE_ROOT/Sources/CalmChat/UIMessage.swift" "$SOURCE_ROOT/Sources/CalmChat/UIStrings.swift" \
  "$SOURCE_ROOT/Sources/CalmChat/AudioDevices.swift" "$SOURCE_ROOT/Sources/CalmChat/VoiceAudio.swift" \
  "$SOURCE_ROOT/Tests/VoiceAudioChecks.swift" -o "$TEST_ROOT/voice-audio-tests"
"$TEST_ROOT/voice-audio-tests"
swiftc -module-cache-path "$TEST_ROOT/module-cache" \
  "$SOURCE_ROOT/Sources/CalmChat/UIMessage.swift" "$SOURCE_ROOT/Sources/CalmChat/UIStrings.swift" \
  "$SOURCE_ROOT/Sources/CalmChatCore/Filter.swift" "$SOURCE_ROOT/Sources/CalmChatCore/ChatGuardState.swift" \
  "$SOURCE_ROOT/Tests/LocalizationChecks.swift" -o "$TEST_ROOT/localization-tests"
"$TEST_ROOT/localization-tests"
