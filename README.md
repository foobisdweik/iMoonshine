# iMoonshine

Two-press Action Button voice transcription. Open app once, then press → speak → press → paste.
Fully on-device via [Moonshine Voice](https://github.com/moonshine-ai/moonshine)
streaming ASR. No network, no accounts, no API keys.

## How it works

1. User launches the app once after install so microphone permission and
   App Shortcut registration are in place.
2. User presses Action Button. Shortcut fires `ToggleRecordingIntent`.
   Intent starts recording + LiveActivity (Dynamic Island shows timer).
   Returns empty string.
3. User speaks. Moonshine small-streaming-en runs inference every 300ms.
   Neural Engine handles tensor math. CPU stays idle.
   One minute is a soft limit only. Dynamic Island warns after 60 seconds,
   but recording continues until the user stops.
4. User presses Action Button again. Shortcut fires intent a second time.
   Intent stops recording, returns transcript via `ReturnsValue<String>`.
   LiveActivity dismissed. Haptic fires.
5. Shortcut's "Copy to Clipboard" node receives transcript string.
   Shortcuts runtime has elevated privileges — bypasses iOS Secure Paste.
6. User long-presses any text field → Paste.

## Why a Shortcut wrapper?

iOS Secure Paste blocks `UIPasteboard.general.string` from background
App Intents on physical devices. Works in Simulator, fails on hardware.
The Shortcuts runtime operates with user-intent privileges and CAN write
to clipboard from background. So the intent exports the string via
`ReturnsValue`, and a one-time user-created Shortcut pipes it to
"Copy to Clipboard".

## User setup (one-time)

1. Install app. Launch once in foreground. Grant microphone permission.
   This also asks the system to refresh the app's shortcuts.
2. Open **Shortcuts** app → tap **+** → new Shortcut.
3. Add action: search "iMoonshine" and pick the iMoonshine action that
   starts and stops recording.
4. If no iMoonshine action appears yet, close Shortcuts, open iMoonshine
   once more, then search again.
5. Add action below: search "Clipboard" → select **"Copy to Clipboard"**.
   Output from the iMoonshine step should auto-wire as input.
6. Open **Settings → Action Button → Shortcut** → pick the Shortcut.

Done. Two presses + paste from now on.

## Architecture

```
Action Button (hardware)
    │
    ▼
Shortcuts daemon
    │ runs Shortcut
    ▼
┌───────────────────────────────────┐
│ ToggleRecordingIntent             │
│   AudioRecordingIntent protocol   │
│   ReturnsValue<String>            │
│   openAppWhenRun = false          │
└───────────┬───────────────────────┘
            │ toggle()
            ▼
┌───────────────────────────────────┐
│ RecordingState (actor singleton)  │
│   start: LiveActivity + mic      │
│   stop: transcript + end LA      │
│   60s:  warning only             │
└───────────┬───────────────────────┘
            │
            ▼
┌───────────────────────────────────┐
│ MoonshineTranscriber              │
│   MicTranscriber (SDK)            │
│   TranscriptEventListener bridge  │
└───────────┬───────────────────────┘
            │ LineCompleted events
            ▼
    completedLines.joined(" ")
            │
            ▼
    IntentResult(value: transcript)
            │
            ▼
    Shortcut "Copy to Clipboard"
            │
            ▼
    UIPasteboard (elevated privileges)
```

## Key protocols

| Protocol | Purpose |
|-|-|
| `AudioRecordingIntent` | Unlimited background execution (bypasses 5-sec watchdog). Requires active LiveActivity. |
| `ReturnsValue<String>` | Exports transcript to Shortcuts runtime for clipboard bypass. |
| `AppShortcutsProvider` | Supplies the iMoonshine app shortcut metadata to Shortcuts. |
| `AppIntentsPackage` | Marks the Swift package target as owning the app intents for bundle discovery. |

## LiveActivity requirement

iOS 18+ mandates an active LiveActivity for `AudioRecordingIntent`.
Without it, perform() throws. The widget extension
(`Sources/iMoonshineWidget/`) provides Dynamic Island + Lock Screen views.
`NSSupportsLiveActivities = YES` in Info.plist.

## Layout

```
iMoonshine/
├── .gitignore
├── Info.plist                     NSMicrophoneUsageDescription,
│                                  UIBackgroundModes=audio,
│                                  NSSupportsLiveActivities=YES
├── WidgetInfo.plist               widget extension manifest
├── Package.swift                  two targets: iMoonshine + iMoonshineWidget
├── xtool.yml                      bundleID + extension config
└── Sources/
    ├── iMoonshine/
    │   ├── iMoonshineApp.swift              @main, scene lifecycle
    │   ├── RootView.swift                   SwiftUI + setup guide
    │   ├── RecordingViewModel.swift         @MainActor event sink
    │   ├── RecordingState.swift             actor, LiveActivity, toggle()
    │   ├── MoonshineTranscriber.swift       MicTranscriber wrapper
    │   ├── ToggleRecordingIntent.swift      AudioRecordingIntent + ReturnsValue
    │   ├── TranscriptionActivityAttributes.swift  ActivityKit model
    │   └── Models/small-streaming-en/       ← drop model files here
    └── iMoonshineWidget/
        └── TranscriptionWidget.swift        Dynamic Island + Lock Screen views
```

## Build (Ubuntu 24.04 + xtool)

```bash
# 1. fetch model (once)
pip install moonshine-voice
python -m moonshine_voice.download --language en --model-arch 4
# copy all 8 files into Sources/iMoonshine/Models/small-streaming-en/

# 2. build + deploy
cd iMoonshine
xtool dev
```

## GitLab macOS CI

If you have GitLab Ultimate, this repo can build an unsigned app bundle on a
hosted macOS runner with `xtool`.

Included files:

- `.gitlab-ci.yml`
- `scripts/ci_macos_unsigned_build.sh`

The CI job:

- runs on `saas-macos-large-m2pro`
- uses `image: macos-26-xcode-26`
- installs `xtool` with Homebrew if needed
- builds an unsigned `xtool/iMoonshine.app`
- audits App Intents metadata in the produced bundle
- uploads artifacts for download

Artifacts produced:

- `artifacts/iMoonshine-release.app.zip`
- `artifacts/appintents-audit-release.txt`
- `artifacts/bundle-manifest-release.txt`

After the job finishes, download the `.app.zip`, unzip it on your machine, and
sideload or sign it however you prefer.

## Troubleshooting Shortcut Discovery

If Shortcuts shows no `iMoonshine` action at all, verify whether the built app
bundle contains App Intents metadata artifacts. A working reference IPA
(`Wispr Flow_v1.55.ipa`) contains all of these:

- `Metadata.appintents/extract.actionsdata`
- `Metadata.appintents/version.json`
- localized `*.lproj/nlu.appintents/*`

Audit your bundle or IPA with:

```bash
python3 scripts/appintents_audit.py xtool/iMoonshine.app
python3 scripts/appintents_audit.py "‎ Wispr Flow_v1.55.ipa"
```

Current finding in this repo:

- `xtool/iMoonshine.app` contains App Intents symbols in the binary
- `xtool` build graph does not show an App Intents metadata extraction step
- no App Intents metadata artifact was present in the packaged app bundle

That means `AppShortcutsProvider`, `updateAppShortcutParameters()`, and
`AppIntentsPackage` are necessary but not sufficient. If the audit still shows
no `Metadata.appintents/` or `nlu.appintents/` after rebuild/reinstall, the
remaining blocker is the build pipeline, not app code.

## Model swap

Edit `MoonshineTranscriber.swift`:

```swift
private static let modelFolderName = "small-streaming-en"
private static var modelArch: ModelArch { .smallStreaming }
```

Arch values: `.tiny`(0) `.base`(1) `.tinyStreaming`(2)
`.baseStreaming`(3) `.smallStreaming`(4) `.mediumStreaming`(5)

## Known constraints

- Free Apple Developer account: provisioning profiles expire after 7 days.
  Re-sign by running `xtool dev` again.
- Action Button flow is most reliable after the app has been opened once in
  the foreground on device.
- No Apple-public hard maximum is documented for `AudioRecordingIntent`
  duration. This app treats 60 seconds as UX guidance, not an enforced stop.
- Widget extension support in xtool is untested — if build fails on the
  extension target, file an issue or build without it (remove extension
  from xtool.yml and Package.swift, change `AudioRecordingIntent` to
  `AppIntent` in ToggleRecordingIntent.swift). Background audio mode
  may keep the process alive long enough without the LiveActivity, but
  the OS may also kill it.
