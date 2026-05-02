import AppIntents
import iMoonshineCore

/// AppIntents extension entry point.
///
/// iOS routes Siri / Shortcuts intent execution through this .appex rather
/// than the main app bundle. linkd opens a connection here, discovers
/// ToggleRecordingIntent via the AppIntentsPackage registration, and calls
/// perform() in-process inside the extension.
///
/// The extension shares RecordingState.shared with the main app via the
/// iMoonshineCore library. Both targets link the same actor, but they run
/// in separate processes — RecordingState.shared in the extension is a
/// distinct instance. The LiveActivity and audio session are the shared
/// observable side-effects that bridge the two processes.
struct iMoonshineIntentsExtension: AppIntentsExtension {
    // AppIntentsExtension conformance is the sole requirement.
    // The runtime discovers ToggleRecordingIntent through iMoonshineIntentsPackage.
}
