import AppIntents
import Foundation
import iMoonshineCore
import os

private let log = Logger(subsystem: "com.foobisdweik.iMoonshine", category: "ToggleRecordingIntent")

/// Action Button entry point.
///
/// Keep this type in the host app module. Apple's own audio-recording
/// reference apps advertise their AudioRecordingIntent actions from the app
/// bundle, and iOS background execution asserts if the metadata points at an
/// app-owned action whose Swift type is actually provided by a package module.
public struct ToggleRecordingIntent: AudioRecordingIntent {

    public static let title: LocalizedStringResource = "Toggle iMoonshine"

    public static let openAppWhenRun: Bool = false
    public static let isDiscoverable: Bool = true

    public init() {}

    public func perform() async throws -> some IntentResult & ReturnsValue<String> {
        print("[VTC] ToggleRecordingIntent.perform entry pid=\(ProcessInfo.processInfo.processIdentifier) bundle=\(Bundle.main.bundleIdentifier ?? "<nil>")")
        log.notice("perform entry pid=\(ProcessInfo.processInfo.processIdentifier, privacy: .public) bundle=\(Bundle.main.bundleIdentifier ?? "<nil>", privacy: .public)")
        do {
            let transcript = try await RecordingState.shared.toggle()
            print("[VTC] ToggleRecordingIntent.perform complete")
            log.notice("perform complete transcriptLength=\(transcript.count, privacy: .public)")
            return .result(value: transcript)
        } catch {
            print("[VTC] ToggleRecordingIntent failed: \(error)")
            log.error("perform failed: \(String(describing: error), privacy: .public)")
            throw error
        }
    }
}

public struct iMoonshineShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
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
