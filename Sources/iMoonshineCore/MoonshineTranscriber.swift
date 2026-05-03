import Foundation
import MoonshineVoice
import os

private let log = Logger(subsystem: "com.foobisdweik.iMoonshine", category: "MoonshineTranscriber")

/// Wraps `MicTranscriber`. Resolves bundled model path, bridges SDK events
/// to an app-local enum so the UI layer stays SDK-agnostic.
final class MoonshineTranscriber: @unchecked Sendable {

    enum Event: Sendable {
        case lineStarted(id: UInt64, text: String)
        case lineTextChanged(id: UInt64, text: String)
        case lineCompleted(id: UInt64, text: String)
        case failure(String)
    }

    /// Set by RecordingState. Called on arbitrary thread — consumer must
    /// marshal to the correct actor.
    var eventSink: (@Sendable (Event) -> Void)?

    private var mic: MicTranscriber?
    private let listener = Listener()

    // MARK: - Model config

    private static let modelFolderName = "small-streaming-en"
    private static var modelArch: ModelArch { .smallStreaming }

    /// Resolve model directory from SPM resource bundle.
    ///
    /// SPM `.copy("Models")` places the folder inside the target's resource
    /// bundle. `Bundle.module` gives access to it at runtime.
    private func resolveModelPath() -> String? {
        // SPM resource bundle path
        if let url = Bundle.module.url(
            forResource: Self.modelFolderName,
            withExtension: nil,
            subdirectory: "Models"
        ) {
            return url.path
        }
        // Fallback: direct child of resource bundle root
        if let base = Bundle.module.resourceURL {
            let candidate = base.appendingPathComponent("Models")
                .appendingPathComponent(Self.modelFolderName)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate.path
            }
        }
        // Last resort: main bundle
        if let url = Bundle.main.url(
            forResource: Self.modelFolderName,
            withExtension: nil
        ) {
            return url.path
        }
        return nil
    }

    // MARK: - Lifecycle

    func loadIfNeeded() {
        guard mic == nil else { return }
        guard let path = resolveModelPath() else {
            print("[VTC] model folder '\(Self.modelFolderName)' not found in bundle")
            log.error("model folder \(Self.modelFolderName, privacy: .public) not found in bundle")
            return
        }
        do {
            log.notice("moonshine load begin path=\(path, privacy: .public)")
            let m = try MicTranscriber(
                modelPath: path,
                modelArch: Self.modelArch,
                updateInterval: 0.3
            )
            listener.owner = self
            m.addListener(listener)
            mic = m
            print("[VTC] moonshine loaded (\(Self.modelFolderName)) from \(path)")
            log.notice("moonshine loaded model=\(Self.modelFolderName, privacy: .public)")
        } catch {
            print("[VTC] moonshine load failed: \(error)")
            log.error("moonshine load failed: \(String(describing: error), privacy: .public)")
        }
    }

    func unload() {
        mic?.close()
        mic = nil
        print("[VTC] moonshine unloaded")
        log.notice("moonshine unloaded")
    }

    // MARK: - Recording

    func start() async throws {
        if mic == nil { loadIfNeeded() }
        guard let mic else { throw TranscriberError.notLoaded }
        log.notice("mic start begin")
        do {
            try mic.start()
            log.notice("mic start ok")
        } catch {
            log.error("mic start failed: \(String(describing: error), privacy: .public)")
            throw error
        }
    }

    func stop() throws {
        log.notice("mic stop begin")
        do {
            try mic?.stop()
            log.notice("mic stop ok")
        } catch {
            log.error("mic stop failed: \(String(describing: error), privacy: .public)")
            throw error
        }
    }

    // MARK: - Emit

    fileprivate func emit(_ event: Event) {
        if case .failure(let message) = event {
            log.error("transcriber event failure: \(message, privacy: .public)")
        }
        eventSink?(event)
    }

    enum TranscriberError: LocalizedError {
        case notLoaded
        var errorDescription: String? {
            "Moonshine transcriber not loaded (model missing from bundle?)"
        }
    }
}

// MARK: - MoonshineVoice listener

private final class Listener: TranscriptEventListener, @unchecked Sendable {
    weak var owner: MoonshineTranscriber?

    func onLineStarted(_ event: LineStarted) {
        owner?.emit(.lineStarted(id: event.line.lineId, text: event.line.text))
    }

    func onLineTextChanged(_ event: LineTextChanged) {
        owner?.emit(.lineTextChanged(id: event.line.lineId, text: event.line.text))
    }

    func onLineCompleted(_ event: LineCompleted) {
        owner?.emit(.lineCompleted(id: event.line.lineId, text: event.line.text))
    }

    func onError(_ event: TranscriptError) {
        owner?.emit(.failure(event.error.localizedDescription))
    }
}
