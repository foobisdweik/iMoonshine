import SwiftUI
import AVFoundation
import AppIntents
import iMoonshineCore

@main
struct iMoonshineApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    init() {
        iMoonshineShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup { RootView() }
            .onChange(of: scenePhase) { _, newPhase in
                Task {
                    switch newPhase {
                    case .active: await RecordingState.shared.preload()
                    default: break
                    }
                }
            }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        AVAudioApplication.requestRecordPermission { granted in
            print("[VTC] mic permission granted=\(granted)")
        }
        Task { await RecordingState.shared.preload() }
        return true
    }
}
