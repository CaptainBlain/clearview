import SwiftUI

@main
struct ClearviewApp: App {
    @State private var capture = CaptureModel()
    @State private var scribble = ScribbleStore()
    private let overlay = OverlayController()

    var body: some Scene {
        MenuBarExtra("Clearview", systemImage: "rectangle.on.rectangle") {
            PanelView(overlay: overlay)
                .environment(capture)
                .environment(scribble)
        }
        .menuBarExtraStyle(.window)

        Window("What they see", id: "viewer") {
            ViewerView()
                .environment(capture)
                .environment(scribble)
        }
        .defaultSize(width: 1100, height: 720)
    }
}
