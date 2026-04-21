import AppIntents

/// Action Button entry point.
///
/// Architecture (from workflow design doc):
///   - Conforms to AudioRecordingIntent → unlimited background execution,
///     bypasses 5-second watchdog. Requires active LiveActivity.
///   - Adopts ReturnsValue<String> → exports transcript to Shortcuts runtime.
///     Shortcuts "Copy to Clipboard" node writes to pasteboard with elevated
///     privileges, bypassing iOS Secure Paste background restriction.
///   - openAppWhenRun = false → pure background, screen stays off.
///
/// User creates a Shortcut:
///   1. Search for iMoonshine in Shortcuts and choose the app action that
///      starts / stops recording
///   2. "Copy to Clipboard" action wired to output
///   3. Assign that Shortcut to Action Button in Settings
///
/// First press:  perform() starts recording + LiveActivity, returns "".
/// Second press: perform() stops recording + LiveActivity, returns transcript.
struct ToggleRecordingIntent: AudioRecordingIntent {

    static let title: LocalizedStringResource = "Toggle iMoonshine"
    static let description = IntentDescription(
        "Start or stop iMoonshine voice transcription.",
        categoryName: "iMoonshine"
    )

    static let openAppWhenRun: Bool = false
    static let isDiscoverable: Bool = true

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let transcript: String
        do {
            transcript = try await RecordingState.shared.toggle()
        } catch {
            transcript = "iMoonshine couldn't start recording. Open app once, confirm microphone and Live Activities are enabled, then try again."
        }
        return .result(value: transcript)
    }
}

struct iMoonshineShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleRecordingIntent(),
            phrases: [
                "Toggle \(.applicationName)",
                "Start \(.applicationName) recording",
                "Stop \(.applicationName) recording"
            ],
            shortTitle: "iMoonshine Toggle",
            systemImageName: "mic.circle.fill"
        )
    }
}
