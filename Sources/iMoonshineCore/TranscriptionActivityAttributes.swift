import ActivityKit
import Foundation

/// Dynamic Island / Lock Screen Live Activity data model.
/// AudioRecordingIntent mandates an active LiveActivity or it fails.
public struct TranscriptionActivityAttributes: ActivityAttributes {
    public init() {}

    /// Static context — doesn't change during the activity.
    public struct ContentState: Codable, Hashable {
        public var elapsedSeconds: Int
        public var isRecording: Bool
        public var isOverSoftLimit: Bool

        public init(elapsedSeconds: Int, isRecording: Bool, isOverSoftLimit: Bool) {
            self.elapsedSeconds = elapsedSeconds
            self.isRecording = isRecording
            self.isOverSoftLimit = isOverSoftLimit
        }
    }
}
