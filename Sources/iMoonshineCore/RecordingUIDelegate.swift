import Foundation

/// Cross-process callback surface that `RecordingState` invokes on the
/// main-app UI layer.
///
/// `RecordingState` lives in `iMoonshineCore` and is shared between the
/// main app process and the AppIntents extension process. The extension
/// has no UI, so this delegate is only attached when the main app is in
/// foreground (`RecordingViewModel.attach()`). When the intent runs from
/// the appex, `setUIDelegate` is never called and the delegate stays nil.
///
/// All callback methods are @MainActor so the conforming view model can
/// mutate published state directly without an extra hop.
@MainActor public protocol RecordingUIDelegate: AnyObject, Sendable {
    func lineStarted(id: UInt64, text: String)
    func lineUpdated(id: UInt64, text: String)
    func lineCompleted(id: UInt64, text: String)
    func didCopyToClipboard(_ text: String)
}
