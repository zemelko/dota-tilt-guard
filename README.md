# Calm Chat 0.4.0

Native Swift / AppKit / SwiftUI utility. Text protection requires macOS 13+; the optional local voice MVP requires macOS 26+. This build targets Apple Silicon. No third-party Swift packages, bundled models, network clients, audio recordings or message history. App bundle file contents: 853,159 bytes.

## Text protection

`NativeChatGuard` installs an active per-process Quartz event tap for Dota after the user enables protection and macOS confirms Accessibility access. It mirrors Escape, Enter, typing, Backspace and Command+A / Control+A. Known abuse suppresses Enter and its key-up. Deleting the entire tracked draft permits Enter to close the empty chat. Unsupported editing and focus loss require Escape to resynchronize.

`ChatFilter` uses normalized Russian/English word and phrase patterns. Coverage is incomplete and can produce false positives. No game memory, injected libraries, game-file edits or synthetic gameplay input. The original user-confirmed text behavior is retained.

## Voice MVP

The selected physical microphone feeds two independent paths:

1. `DictationTranscriber` / `SpeechAnalyzer` receive continuous audio for local transcription, even while outgoing audio is muted.
2. A bounded mono PCM queue and a second `AVAudioEngine` send audio to BlackHole 2ch. A detection clears the queue and outputs zeros for three seconds. A new detection extends the pause. Silence and speech with no new detections allow transmission to resume.

The app changes the system default input to BlackHole **before creating the audio engines**, then explicitly binds capture to the selected physical microphone. Doing this after engine startup caused capture to migrate to the virtual device and receive silence on this Mac. The UI displays actual capture and output device names.

Recognition uses installed macOS dictation assets only. It does not request downloads or use remote recognition. Russian and English are selectable; both local assets are present on this Mac. Profanity replacement is explicitly disabled. One current transcript is displayed in memory, without persisted history. Partial and final hypotheses share utterance/word-position identities so finalization does not reset the cooldown for an old word.

The first abusive word can escape before recognition. This MVP does not detect intonation and does not promise complete abuse coverage. Applications explicitly using a different microphone bypass the virtual input. Recognition/audio errors mute transmission until restart. Switching the system input elsewhere shows an error but cannot prevent another application from using that input. On normal stop or quit, the previous system input is restored when available; restoration failures are shown. After a crash, select a physical input in macOS Sound settings if BlackHole remains selected.

BlackHole 2ch is a separately installed dependency, not part of this app or source archive. The official 0.7.1 installer was verified against its published checksum and Apple-trusted installer signature; the user installed it and rebooted. Expected device UID is `BlackHole2ch_UID` with two input and output channels.

References: [Apple DictationTranscriber](https://developer.apple.com/documentation/speech/dictationtranscriber), [BlackHole](https://existential.audio/blackhole/).

## Build, test and retain versions

Requires Apple Command Line Tools with a macOS 26+ SDK. Quit the running app before rebuilding.

```sh
./scripts/test.sh '/absolute/path/checks'
./scripts/build.sh '/absolute/path/Calm Chat.app' '/absolute/path/build'
./scripts/dmg.sh '/absolute/path/Calm Chat.app' '/absolute/path/output' '/absolute/path/work'
./scripts/archive-release.sh '/absolute/path/Calm Chat.app' '/absolute/path/releases'
```

The build signs a clean staged bundle before replacing the current app. `archive-release.sh` saves an app, its corresponding source snapshot and checksums under its version number. Existing releases cannot be overwritten. Increase the version before saving another release. Version 0.3.1 is preserved as the original working binary; its original source snapshot was not retained. Starting with 0.4.0, archives include sources.

Releases share a bundle identifier and should be run one at a time. The main `outputs/Calm Chat.app` is the current build. Older apps are available under `outputs/releases/<version>/Calm Chat.app`.

## Permissions

Text protection needs Accessibility; voice protection needs Microphone access. The ad-hoc signature changes when executable contents change. macOS may show an enabled Accessibility switch for an older signature. Re-add the current app with the Accessibility “+” button, or remove only the stale Calm Chat entry and add it again. Do not modify TCC databases or weaken signing requirements. A stable distribution signing identity would avoid these development-build permission refreshes.

## Verification

- Eight core scenarios / 75 assertions: filtering, chat input state, select-all deletion, voice cooldown, repeated hypotheses and new abusive words.
- PCM checks: mute outputs zeros, continued input metering during mute, queued audio is discarded, fresh audio resumes, both output channels match, bounded backlog, independent capture buffers and continuous sample-rate conversion.
- Synthetic Russian and English speech through the actual local recognizer: one abusive phrase triggers one detection in each language; partial/final updates do not retrigger it; cooldown recovers.
- Live MacBook microphone: recognized speech and detections visible in the app after fixing device order; the user reports that it appears to work.
- Independent BlackHole input meter: nonzero transmitted audio, zero samples during mute and resumed audio afterward; only numerical levels were collected, no microphone audio was saved.

An in-game voice confirmation remains a user check. Reading the virtual device proves audio routing, but does not prove which input a particular Dota session has selected.
