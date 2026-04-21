import ActivityKit
import Foundation

/// Dynamic Island / Lock Screen Live Activity data model.
/// AudioRecordingIntent mandates an active LiveActivity or it fails.
struct TranscriptionActivityAttributes: ActivityAttributes {
    /// Static context — doesn't change during the activity.
    struct ContentState: Codable, Hashable {
        var elapsedSeconds: Int
        var isRecording: Bool
        var isOverSoftLimit: Bool
    }
}
