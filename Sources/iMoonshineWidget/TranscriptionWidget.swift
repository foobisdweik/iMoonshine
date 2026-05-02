import ActivityKit
import SwiftUI
import WidgetKit
import iMoonshineCore

@main
struct iMoonshineWidgetBundle: WidgetBundle {
    var body: some Widget {
        TranscriptionLiveActivity()
    }
}

struct TranscriptionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TranscriptionActivityAttributes.self) { context in
            // Lock Screen presentation
            HStack {
                Image(systemName: context.state.isRecording ? "mic.fill" : "mic.slash")
                    .foregroundColor(accentColor(for: context))
                VStack(alignment: .leading) {
                    Text(statusText(for: context))
                        .font(.headline)
                    Text(formatTime(context.state.elapsedSeconds))
                        .font(.caption)
                        .monospacedDigit()
                }
                Spacer()
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "mic.fill")
                        .foregroundColor(accentColor(for: context))
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(formatTime(context.state.elapsedSeconds))
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(trailingText(for: context))
                        .font(.caption2)
                        .foregroundColor(accentColor(for: context))
                }
            } compactLeading: {
                Image(systemName: "mic.fill")
                    .foregroundColor(accentColor(for: context))
            } compactTrailing: {
                Text(formatTime(context.state.elapsedSeconds))
                    .monospacedDigit()
                    .font(.caption2)
            } minimal: {
                Image(systemName: "mic.fill")
                    .foregroundColor(accentColor(for: context))
            }
        }
    }
}

private func formatTime(_ seconds: Int) -> String {
    let m = seconds / 60
    let s = seconds % 60
    return String(format: "%d:%02d", m, s)
}

private func accentColor(for context: ActivityViewContext<TranscriptionActivityAttributes>) -> Color {
    context.state.isOverSoftLimit ? .orange : (context.state.isRecording ? .red : .gray)
}

private func statusText(for context: ActivityViewContext<TranscriptionActivityAttributes>) -> String {
    if !context.state.isRecording {
        return "Finalizing…"
    }
    return context.state.isOverSoftLimit ? "Over 1 min" : "Recording…"
}

private func trailingText(for context: ActivityViewContext<TranscriptionActivityAttributes>) -> String {
    if !context.state.isRecording {
        return "…"
    }
    return context.state.isOverSoftLimit ? "1M+" : "REC"
}
