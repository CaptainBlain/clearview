import SwiftUI

/// The menu bar panel: pick a display, choose apps to hide, share.
struct PanelView: View {
    @Environment(CaptureModel.self) private var capture
    @Environment(ScribbleStore.self) private var scribble
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    let overlay: OverlayController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Clearview").font(.headline)
                Spacer()
                if capture.isSharing {
                    Label("Sharing", systemImage: "circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            section("SCREEN") {
                Picker("Screen", selection: Binding(
                    get: { capture.selectedDisplayID ?? 0 },
                    set: { capture.selectDisplay($0) }
                )) {
                    ForEach(capture.displays, id: \.displayID) { display in
                        Text(capture.displayName(display)).tag(display.displayID)
                    }
                }
                .labelsHidden()
            }

            section("HIDE FROM SHARING") {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(capture.apps) { app in
                            HStack(spacing: 8) {
                                if let icon = app.icon {
                                    Image(nsImage: icon).resizable().frame(width: 20, height: 20)
                                }
                                Text(app.name).lineLimit(1)
                                Spacer()
                                Toggle(app.name, isOn: Binding(
                                    get: { capture.hiddenBundleIDs.contains(app.id) },
                                    set: { capture.setHidden(app.id, $0) }
                                ))
                                .toggleStyle(.switch)
                                .controlSize(.mini)
                                .labelsHidden()
                            }
                        }
                    }
                }
                .frame(maxHeight: 240)
            }

            if let error = capture.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.clearviewRose)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: toggleSharing) {
                Text(capture.isSharing ? "Stop sharing" : "Share")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(capture.isSharing ? .gray : .clearviewRose)

            Divider()
            Button("Quit Clearview") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 300)
        .preferredColorScheme(.dark)
        .task { await capture.refresh() }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .tracking(1)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func toggleSharing() {
        Task {
            if capture.isSharing {
                await capture.stop()
                overlay.hide()
                dismissWindow(id: "viewer")
            } else {
                await capture.start()
                guard capture.isSharing else { return }
                overlay.show(on: capture.selectedDisplayID, strokes: scribble)
                openWindow(id: "viewer")
                NSApp.activate()
            }
        }
    }
}
