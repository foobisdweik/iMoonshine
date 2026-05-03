import ActivityKit
import AVFoundation
import Foundation
import os
import UIKit

private let log = Logger(subsystem: "com.foobisdweik.iMoonshine", category: "Recording")

public actor RecordingState {

    public static let shared = RecordingState()
    private init() {}

    private static let softLimitSeconds = 60

    public private(set) var isRecording = false

    private let transcriber = MoonshineTranscriber()
    private weak var uiDelegate: (any RecordingUIDelegate)?

    private var completedLines: [String] = []
    private var activeLines: [UInt64: String] = [:]
    private var timerTask: Task<Void, Never>?
    private var recordingStartTime: Date?

    // MARK: - Lifecycle

    public func preload() { transcriber.loadIfNeeded() }
    public func unload()  { transcriber.unload() }

    // MARK: - UI hook

    public func setUIDelegate(_ delegate: any RecordingUIDelegate) {
        self.uiDelegate = delegate
        transcriber.eventSink = { [weak self] event in
            Task { await self?.forward(event) }
        }
    }

    // MARK: - Toggle (returns transcript on stop, current clipboard on start)

    /// Called by ToggleRecordingIntent.perform() and RecordingViewModel.toggle().
    /// Returns transcript string on stop (used by ReturnsValue for Shortcuts
    /// clipboard bypass). Returns current clipboard on start to avoid wiping it.
    @discardableResult
    public func toggle() async throws -> String {
        print("[VTC] RecordingState.toggle isRecording=\(isRecording) pid=\(ProcessInfo.processInfo.processIdentifier) bundle=\(Bundle.main.bundleIdentifier ?? "<nil>")")
        log.notice("toggle isRecording=\(self.isRecording, privacy: .public) pid=\(ProcessInfo.processInfo.processIdentifier, privacy: .public) bundle=\(Bundle.main.bundleIdentifier ?? "<nil>", privacy: .public)")
        if isRecording {
            return try await stop()
        } else {
            try await start()
            // Avoid touching UIPasteboard while the app is background-launched
            // for an intent; iOS may terminate background pasteboard access.
            return await MainActor.run {
                UIApplication.shared.applicationState == .active
                    ? UIPasteboard.general.string ?? ""
                    : ""
            }
        }
    }

    private func start() async throws {
        print("[VTC] RecordingState.start begin")
        log.notice("start begin")
        completedLines.removeAll()
        activeLines.removeAll()
        recordingStartTime = Date()

        let permission = AVAudioSession.sharedInstance().recordPermission
        let appState = await MainActor.run { UIApplication.shared.applicationState.rawValue }
        log.notice("start preflight appState=\(appState, privacy: .public) micPermission=\(String(describing: permission), privacy: .public)")
        guard permission == .granted else {
            log.error("microphone permission not granted")
            throw RecordingPermissionError.microphoneNotGranted
        }

        // AudioRecordingIntent requires a Live Activity for an active
        // background audio session. Start it before activating AVAudioSession;
        // otherwise AppIntents traps after perform() returns.
        print("[VTC] RecordingState.start liveActivity start")
        log.notice("start liveActivity begin")
        try await LiveActivityController.start()
        log.notice("start liveActivity ok")

        // Configure audio session for background recording.
        // .record (not .playAndRecord) — mic only, no playback path.
        // .mixWithOthers — required for AudioRecordingIntent dispatch from
        // BG-Active state; without it, audiomxd denies setActive(true) with
        // -12985 ("Cannot interrupt others") when other audio is active.
        let session = AVAudioSession.sharedInstance()
        print("[VTC] RecordingState.start setCategory")
        log.notice("start setCategory")
        try session.setCategory(.record, mode: .default, options: [.allowBluetooth, .mixWithOthers])
        print("[VTC] RecordingState.start audio configured")
        log.notice("start audio configured")

        do {
            print("[VTC] RecordingState.start transcriber start")
            log.notice("start transcriber begin")
            try await transcriber.start()
        } catch {
            print("[VTC] RecordingState.start transcriber failed: \(error)")
            log.error("start transcriber failed: \(String(describing: error), privacy: .public)")
            recordingStartTime = nil
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            await endLiveActivity()
            throw error
        }
        isRecording = true
        print("[VTC] RecordingState.start complete")
        log.notice("start complete")

        // Periodic timer to update Dynamic Island elapsed seconds.
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                await self?.updateLiveActivity()
            }
        }
    }

    private func stop() async throws -> String {
        print("[VTC] RecordingState.stop begin")
        log.notice("stop begin")
        timerTask?.cancel()
        timerTask = nil

        try transcriber.stop()
        print("[VTC] RecordingState.stop transcriber stopped")
        log.notice("stop transcriber stopped")
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        print("[VTC] RecordingState.stop audio inactive")
        log.notice("stop audio inactive")
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

        if let vm = uiDelegate, !full.isEmpty {
            await MainActor.run { vm.didCopyToClipboard(full) }
        } else if !full.isEmpty {
            let canWritePasteboard = await MainActor.run { UIApplication.shared.applicationState == .active }
            if canWritePasteboard {
                await MainActor.run {
                    UIPasteboard.general.string = full
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
        }

        print("[VTC] RecordingState.stop complete transcriptLength=\(full.count)")
        log.notice("stop complete transcriptLength=\(full.count, privacy: .public)")
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
    static func start() async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[VTC] Live Activities not enabled")
            log.error("Live Activities not enabled")
            throw LiveActivityError.notAuthorized
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
            log.notice("LiveActivity started")
        } catch {
            print("[VTC] LiveActivity failed: \(error)")
            log.error("LiveActivity failed: \(String(describing: error), privacy: .public)")
            throw error
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
        log.notice("LiveActivity ended")
    }
}

private enum LiveActivityError: LocalizedError {
    case notAuthorized

    var errorDescription: String? {
        "Live Activities are not enabled for iMoonshine."
    }
}

private enum RecordingPermissionError: LocalizedError {
    case microphoneNotGranted

    var errorDescription: String? {
        "Open iMoonshine once and allow microphone access."
    }
}
