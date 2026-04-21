import Foundation
import SwiftUI
import UIKit

@MainActor
final class RecordingViewModel: ObservableObject {

    struct LineItem: Identifiable, Equatable {
        let id: UInt64
        var text: String
    }

    @Published var lines: [LineItem] = []
    @Published var isRecording = false
    @Published var errorMessage: String?

    func attach() async {
        await RecordingState.shared.setUIDelegate(self)
        isRecording = await RecordingState.shared.isRecording
    }

    func toggle() async {
        do {
            errorMessage = nil
            try await RecordingState.shared.toggle()
            isRecording = await RecordingState.shared.isRecording
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func lineStarted(id: UInt64, text: String) {
        lines.append(LineItem(id: id, text: text))
    }

    func lineUpdated(id: UInt64, text: String) {
        if let i = lines.firstIndex(where: { $0.id == id }) {
            lines[i].text = text
        } else {
            lines.append(LineItem(id: id, text: text))
        }
    }

    func lineCompleted(id: UInt64, text: String) {
        if text.isEmpty {
            lines.removeAll { $0.id == id }
        } else if let i = lines.firstIndex(where: { $0.id == id }) {
            lines[i].text = text
        }
    }

    func didCopyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
