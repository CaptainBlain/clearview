import XCTest
@testable import Clearview

@MainActor
final class ScribbleStoreTests: XCTestCase {
    func testStrokeBeingDrawnIsFullyOpaque() {
        let store = ScribbleStore()
        store.begin(at: CGPoint(x: 0.1, y: 0.1))
        store.extend(to: CGPoint(x: 0.2, y: 0.2))
        XCTAssertEqual(store.current?.points.count, 2)
        XCTAssertEqual(store.opacity(of: store.current!, at: Date()), 1)
    }

    func testFinishedStrokeHoldsThenFades() {
        let store = ScribbleStore()
        store.begin(at: .zero)
        store.end()
        let stroke = store.strokes[0]
        let done = stroke.finishedAt!
        XCTAssertEqual(store.opacity(of: stroke, at: done.addingTimeInterval(ScribbleStore.holdTime - 0.1)), 1)
        let halfway = done.addingTimeInterval(ScribbleStore.holdTime + ScribbleStore.fadeTime / 2)
        XCTAssertEqual(store.opacity(of: stroke, at: halfway), 0.5, accuracy: 0.001)
        XCTAssertEqual(store.opacity(of: stroke, at: done.addingTimeInterval(60)), 0)
    }

    func testPruneDropsFadedStrokesOnly() {
        let store = ScribbleStore()
        store.begin(at: .zero)
        store.end()
        store.begin(at: .zero)
        store.end()
        store.strokes[0].finishedAt = Date().addingTimeInterval(-60)
        store.prune(now: Date())
        XCTAssertEqual(store.strokes.count, 1)
    }

    func testStrokeUsesToolChosenWhenItStarted() {
        let store = ScribbleStore()
        store.tool = .arrow
        store.begin(at: .zero)
        store.tool = .pen
        store.end()
        XCTAssertEqual(store.strokes[0].tool, .arrow)
    }
}
