import SwiftUI
import ActivityKit

struct RootView: View {
    @StateObject private var vm = RecordingViewModel()
    @State private var showSetup = false
    @State private var liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("iMoonshine")
                    .font(.headline)
                Spacer()
                Button(action: { showSetup.toggle() }) {
                    Image(systemName: "questionmark.circle")
                }
            }
            .padding()

            if !liveActivitiesEnabled {
                liveActivityWarning
            }

            if let errorMessage = vm.errorMessage {
                errorBanner(errorMessage)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if vm.lines.isEmpty {
                            VStack(spacing: 20) {
                                Text("Open app once, then use Action Button")
                                    .foregroundColor(.gray)

                                setupInstructions
                            }
                            .padding(.top, 40)
                        } else {
                            ForEach(vm.lines) { line in
                                Text(line.text)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                    .padding(.vertical, 4)
                                    .id(line.id)
                            }
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                }
                .onChange(of: vm.lines.count) { _, _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }

            controlButton
        }
        .sheet(isPresented: $showSetup) {
            setupSheet
        }
        .task { await vm.attach() }
        .onAppear {
            liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
        }
    }

    private var liveActivityWarning: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Live Activities disabled").font(.caption).bold()
                Text("Action Button recording will fail on iOS 18+. Enable in Settings.")
                    .font(.caption2).foregroundColor(.secondary)
            }
            Spacer()
            Button("Open") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.15))
        .cornerRadius(8)
        .padding(.horizontal)
    }

    private var setupInstructions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Action Button Setup:").font(.caption).bold()
            Text("1. Launch iMoonshine once and grant microphone access").font(.caption)
            Text("2. Open Shortcuts app").font(.caption)
            Text("3. Tap + to create new Shortcut").font(.caption)
            Text("4. Search for \"iMoonshine\" in Add Action").font(.caption)
            Text("5. Choose the iMoonshine action that starts/stops recording").font(.caption)
            Text("6. Add action: \"Copy to Clipboard\"").font(.caption)
            Text("7. Settings → Action Button → Shortcut").font(.caption)
            Text("8. Choose your new Shortcut").font(.caption)
            Spacer().frame(height: 4)
            Text("Press Action Button to start recording.")
                .font(.caption).italic()
            Text("If no iMoonshine action appears, close Shortcuts, open iMoonshine once more, then search again.")
                .font(.caption).italic()
            Text("One-minute mark is warning only. Press again to stop, then paste anywhere.")
                .font(.caption).italic()
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }

    private var setupSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        stepView(number: "1", title: "Launch Once",
                                 detail: "Open iMoonshine in the foreground after install. Grant microphone permission so Action Button runs have everything they need.")
                        stepView(number: "2", title: "Create Shortcut",
                                 detail: "Open the Shortcuts app. Tap + in the top right to create a new Shortcut.")
                        stepView(number: "3", title: "Find iMoonshine Action",
                                 detail: "Tap \"Add Action\". Search for \"iMoonshine\". Pick the iMoonshine action that starts and stops recording. If nothing appears yet, leave Shortcuts, open iMoonshine once more, then search again.")
                        stepView(number: "4", title: "Add Clipboard Action",
                                 detail: "Tap + below the first action. Add an If block for when the iMoonshine output has any value. Inside it, add Copy to Clipboard and set Content to the iMoonshine output magic variable.")
                        stepView(number: "5", title: "Assign to Action Button",
                                 detail: "Open Settings → Action Button → Shortcut. Pick the Shortcut you created.")
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Usage").font(.headline)
                        Text("Press Action Button → speak → press again → paste anywhere.")
                            .font(.subheadline)
                        Text("Dynamic Island shows timer and warns after one minute. Recording keeps going until you press again.")
                            .font(.caption).foregroundColor(.secondary)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Why a Shortcut?").font(.headline)
                        Text("iOS Secure Paste blocks background apps from writing to the clipboard. The Shortcuts runtime has elevated privileges to bypass this restriction.")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Setup")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showSetup = false }
                }
            }
        }
    }

    private func stepView(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.title2).bold()
                .foregroundColor(.blue)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline).bold()
                Text(detail).font(.caption).foregroundColor(.secondary)
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.12))
        .cornerRadius(8)
        .padding(.horizontal)
    }

    private var controlButton: some View {
        Button {
            Task { await vm.toggle() }
        } label: {
            Image(systemName: vm.isRecording ? "stop.fill" : "mic")
                .font(.system(size: 36))
                .foregroundColor(vm.isRecording ? .red : .blue)
                .padding()
                .background(
                    Circle().fill(vm.isRecording ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                )
        }
        .padding(.bottom, 24)
    }
}
