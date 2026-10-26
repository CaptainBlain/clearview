import AppKit
import SwiftUI

/// A transparent, click-through window over the shared display that shows the
/// strokes drawn in the viewer, the "you draw on her screen" half of Scribble.
/// It belongs to Clearview, so the capture filter keeps it out of the stream.
@MainActor
final class OverlayController {
    private var window: NSWindow?

    func show(on displayID: CGDirectDisplayID?, strokes: ScribbleStore) {
        guard let screen = NSScreen.screens.first(where: { $0.displayID == displayID }) ?? NSScreen.main else { return }
        let window = self.window ?? makeWindow()
        window.contentView = NSHostingView(rootView: StrokesCanvas(store: strokes))
        window.setFrame(screen.frame, display: true)
        window.orderFrontRegardless()
        self.window = window
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isReleasedWhenClosed = false
        return window
    }
}
