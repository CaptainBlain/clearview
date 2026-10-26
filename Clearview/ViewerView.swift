import SwiftUI

/// "What they see": the live capture with hidden apps removed, plus Scribble.
/// Hold ⌥ (or switch Scribble on) and drag to draw.
struct ViewerView: View {
    @Environment(CaptureModel.self) private var capture
    @Environment(ScribbleStore.self) private var scribble
    @State private var scribbleOn = false

    var body: some View {
        @Bindable var scribble = scribble
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("WHAT THEY SEE")
                    .font(.caption.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(Color.clearviewRose)
                Spacer()
                Picker("Tool", selection: $scribble.tool) {
                    ForEach(ScribbleTool.allCases) { tool in
                        Label(tool.label, systemImage: tool.symbol).tag(tool)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                Toggle("Scribble (or hold ⌥)", isOn: $scribbleOn)
                    .toggleStyle(.button)
                Spacer()
                TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                    Text(stats)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            ZStack {
                FrameView(frames: capture.frames)
                StrokesCanvas(store: scribble, imageRect: imageRect)
                GeometryReader { geo in
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(drawing(in: geo.size))
                }
                if !capture.isSharing {
                    Text("Not sharing. Press Share in the menu bar.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .background(Color(white: 0.08))
        .preferredColorScheme(.dark)
        .frame(minWidth: 640, minHeight: 420)
    }

    private var stats: String {
        guard capture.isSharing else { return "" }
        return "\(Int(capture.frameSize.width))×\(Int(capture.frameSize.height)) · \(capture.frames.framesPerSecond) fps"
    }

    private func imageRect(_ size: CGSize) -> CGRect {
        Geometry.aspectFit(capture.frameSize, in: CGRect(origin: .zero, size: size))
    }

    private func drawing(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let point = Geometry.normalize(value.location, in: imageRect(size))
                if scribble.current == nil {
                    guard capture.isSharing, scribbleOn || NSEvent.modifierFlags.contains(.option) else { return }
                    scribble.begin(at: point)
                } else {
                    scribble.extend(to: point)
                }
            }
            .onEnded { _ in scribble.end() }
    }
}
