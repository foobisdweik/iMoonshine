import ActivityKit
import Foundation
import UIKit

actor RecordingState {

    static let shared = RecordingState()
    private init() {}

    private static let softLimitSeconds = 60

    private(set) var isRecording = false

    private let transcriber = MoonshineTranscriber()
    private weak var uiDelegate: RecordingViewModel?

    private var completedLines: [String] = []
    private var activeLines: [UInt64: String] = [:]
    private var timerTask: Task<Void, Never>?
    private var recordingStartTime: Date?

    // MARK: - Lifecycle

    func preload() { transcriber.loadIfNeeded() }
    func unload()  { transcriber.unload() }

    // MARK: - UI hook

    func setUIDelegate(_ vm: RecordingViewModel) {
        self.uiDelegate = vm
        transcriber.eventSink = { [weak self] event in
            Task { await self?.forward(event) }
        }
    }

    // MARK: - Toggle (returns transcript on stop, "" on start)

    /// Called by ToggleRecordingIntent.perform() and RecordingViewModel.toggle().
    /// Returns transcript string on stop (used by ReturnsValue for Shortcuts
    /// clipboard bypass). Returns "" on start.
    @discardableResult
    func toggle() async throws -> String {
        if isRecording {
            return try await stop()
        } else {
            try await start()
            return ""
        }
    }

    private func start() async throws {
        completedLines.removeAll()
        activeLines.removeAll()
        recordingStartTime = Date()

        // LiveActivity must be active BEFORE AudioRecordingIntent considers
        // the background audio session valid on iOS 18+.
        await LiveActivityController.start()

        do {
            try await transcriber.start()
        } catch {
            recordingStartTime = nil
            await endLiveActivity()
            throw error
        }
        isRecording = true

        // Periodic timer to update Dynamic Island elapsed seconds.
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                await self?.updateLiveActivity()
            }
        }
    }

    private func stop() async throws -> String {
        timerTask?.cancel()
        timerTask = nil

        try transcriber.stop()
        isRecording = false

        let partialLines = activeLines
            .sorted { $0.key < $1.key }
            .map(\.value)
            .filter { !$0.isEmpty }
        activeLines.removeAll()

        let full = (completedLines + partialLines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        await endLiveActivity()

        // If app is in foreground (uiDelegate set), also copy directly +
        // fire haptic. For background intent path, ReturnsValue handles
        // clipboard via Shortcuts runtime.
        if let vm = uiDelegate, !full.isEmpty {
            await MainActor.run { vm.didCopyToClipboard(full) }
        } else if !full.isEmpty {
            // Fire haptic even from background to signal completion.
            await MainActor.run {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }

        return full
    }

    private func updateLiveActivity() async {
        guard let startTime = recordingStartTime else { return }
        let elapsed = Int(Date().timeIntervalSince(startTime))
        await LiveActivityController.update(
            elapsedSeconds: elapsed,
            isRecording: true,
            isOverSoftLimit: elapsed >= Self.softLimitSeconds
        )
    }

    private func endLiveActivity() async {
        await LiveActivityController.end(
            elapsedSeconds: 0,
            isRecording: false,
            isOverSoftLimit: false
        )
    }

    // MARK: - Event forwarding

    private func forward(_ event: MoonshineTranscriber.Event) async {
        switch event {
        case .lineStarted(let id, let text):
            activeLines[id] = text
            let delegate = uiDelegate
            await MainActor.run { delegate?.lineStarted(id: id, text: text) }
        case .lineTextChanged(let id, let text):
            activeLines[id] = text
            let delegate = uiDelegate
            await MainActor.run { delegate?.lineUpdated(id: id, text: text) }
        case .lineCompleted(let id, let text):
            activeLines.removeValue(forKey: id)
            if !text.isEmpty { completedLines.append(text) }
            let delegate = uiDelegate
            await MainActor.run { delegate?.lineCompleted(id: id, text: text) }
        case .failure(let msg):
            print("[VTC] transcriber error: \(msg)")
        }
    }
}

private enum LiveActivityController {
    static func start() async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[VTC] Live Activities not enabled")
            return
        }

        let attributes = TranscriptionActivityAttributes()
        let state = TranscriptionActivityAttributes.ContentState(
            elapsedSeconds: 0,
            isRecording: true,
            isOverSoftLimit: false
        )

        do {
            _ = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            print("[VTC] LiveActivity started")
        } catch {
            print("[VTC] LiveActivity failed: \(error)")
        }
    }

    static func update(elapsedSeconds: Int, isRecording: Bool, isOverSoftLimit: Bool) async {
        guard let activity = Activity<TranscriptionActivityAttributes>.activities.first else { return }

        let state = TranscriptionActivityAttributes.ContentState(
            elapsedSeconds: elapsedSeconds,
            isRecording: isRecording,
            isOverSoftLimit: isOverSoftLimit
        )

        await activity.update(.init(state: state, staleDate: nil))
    }

    static func end(elapsedSeconds: Int, isRecording: Bool, isOverSoftLimit: Bool) async {
        guard let activity = Activity<TranscriptionActivityAttributes>.activities.first else { return }

        let state = TranscriptionActivityAttributes.ContentState(
            elapsedSeconds: elapsedSeconds,
            isRecording: isRecording,
            isOverSoftLimit: isOverSoftLimit
        )

        await activity.end(
            .init(state: state, staleDate: nil),
            dismissalPolicy: .immediate
        )
        print("[VTC] LiveActivity ended")
    }
}
