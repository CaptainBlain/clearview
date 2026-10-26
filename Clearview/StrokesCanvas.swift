import SwiftUI

extension Color {
    static let clearviewRose = Color(red: 0.96, green: 0.25, blue: 0.37)
}

/// Draws the shared strokes inside `imageRect`. Used both over the viewer and
/// in the overlay on the real screen, so both sides see the same drawing.
struct StrokesCanvas: View {
    let store: ScribbleStore
    var imageRect: (CGSize) -> CGRect = { CGRect(origin: .zero, size: $0) }

    var body: some View {
        TimelineView(.animation(paused: store.isEmpty)) { timeline in
            Canvas { context, size in
                let rect = imageRect(size)
                for stroke in store.visibleStrokes {
                    let opacity = store.opacity(of: stroke, at: timeline.date)
                    guard opacity > 0 else { continue }
                    let points = stroke.points.map { Geometry.denormalize($0, in: rect) }
                    var layer = context
                    layer.opacity = opacity
                    draw(stroke.tool, points: points, in: &layer)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func draw(_ tool: ScribbleTool, points: [CGPoint], in context: inout GraphicsContext) {
        guard let first = points.first, let last = points.last else { return }
        let round = StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
        switch tool {
        case .pen:
            context.stroke(polyline(points), with: .color(.clearviewRose), style: round)
        case .highlight:
            context.stroke(polyline(points),
                           with: .color(.yellow.opacity(0.4)),
                           style: StrokeStyle(lineWidth: 22, lineCap: .round, lineJoin: .round))
        case .arrow:
            var path = Path()
            path.move(to: first)
            path.addLine(to: last)
            let angle = atan2(last.y - first.y, last.x - first.x)
            for side in [-1.0, 1.0] {
                let wing = angle + .pi - side * .pi / 7
                path.move(to: last)
                path.addLine(to: CGPoint(x: last.x + 18 * cos(wing), y: last.y + 18 * sin(wing)))
            }
            context.stroke(path, with: .color(.clearviewRose), style: round)
        }
    }

    private func polyline(_ points: [CGPoint]) -> Path {
        var path = Path()
        path.addLines(points.count == 1 ? [points[0], points[0]] : points)
        return path
    }
}
