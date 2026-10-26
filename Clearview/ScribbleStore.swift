import Foundation
import Observation

enum ScribbleTool: String, CaseIterable, Identifiable {
    case pen, arrow, highlight

    var id: Self { self }

    var label: String {
        switch self {
        case .pen: "Pen"
        case .arrow: "Arrow"
        case .highlight: "Highlight"
        }
    }

    var symbol: String {
        switch self {
        case .pen: "pencil.tip"
        case .arrow: "arrow.up.right"
        case .highlight: "highlighter"
        }
    }
}

struct Stroke: Identifiable {
    let id = UUID()
    let tool: ScribbleTool
    var points: [CGPoint]
    var finishedAt: Date?
}

/// Strokes shared by the viewer and the on-screen overlay, so both sides see
/// the same drawing. Finished strokes hold for a moment, then fade out.
@MainActor
@Observable
final class ScribbleStore {
    static let holdTime: TimeInterval = 3
    static let fadeTime: TimeInterval = 0.6

    var tool: ScribbleTool = .pen
    var strokes: [Stroke] = []
    var current: Stroke?

    var visibleStrokes: [Stroke] {
        current.map { strokes + [$0] } ?? strokes
    }

    var isEmpty: Bool { strokes.isEmpty && current == nil }

    func begin(at point: CGPoint) {
        current = Stroke(tool: tool, points: [point])
    }

    func extend(to point: CGPoint) {
        current?.points.append(point)
    }

    func end() {
        guard var stroke = current else { return }
        stroke.finishedAt = Date()
        strokes.append(stroke)
        current = nil
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.holdTime + Self.fadeTime + 0.1))
            self?.prune(now: Date())
        }
    }

    func opacity(of stroke: Stroke, at now: Date) -> Double {
        guard let finishedAt = stroke.finishedAt else { return 1 }
        let fading = now.timeIntervalSince(finishedAt) - Self.holdTime
        return fading <= 0 ? 1 : max(0, 1 - fading / Self.fadeTime)
    }

    func prune(now: Date) {
        strokes.removeAll { opacity(of: $0, at: now) == 0 }
    }
}
