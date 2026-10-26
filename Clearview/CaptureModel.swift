import AppKit
import Observation
import ScreenCaptureKit

/// Owns the ScreenCaptureKit stream: which display is shared, which apps are
/// hidden from it, and whether it is running. Hiding an app mid-share swaps
/// the stream's content filter without restarting it.
@MainActor
@Observable
final class CaptureModel {
    struct AppItem: Identifiable {
        let id: String
        let name: String
        let icon: NSImage?
    }

    var displays: [SCDisplay] = []
    var selectedDisplayID: CGDirectDisplayID?
    var apps: [AppItem] = []
    var hiddenBundleIDs: Set<String> = []
    var isSharing = false
    var errorMessage: String?
    /// Pixel size of the frames being captured.
    var frameSize: CGSize = .zero

    let frames = FrameStore()

    private var content: SCShareableContent?
    private var stream: SCStream?
    private let output: StreamOutput
    private let delegate = CaptureStreamDelegate()
    private let ownBundleID = Bundle.main.bundleIdentifier

    init() {
        output = StreamOutput(frames: frames)
        delegate.onStop = { [weak self] error in
            Task { @MainActor in
                self?.stream = nil
                self?.isSharing = false
                self?.errorMessage = error.localizedDescription
            }
        }
    }

    var selectedDisplay: SCDisplay? {
        displays.first { $0.displayID == selectedDisplayID }
    }

    func displayName(_ display: SCDisplay) -> String {
        let screen = NSScreen.screens.first { $0.displayID == display.displayID }
        return "\(screen?.localizedName ?? "Display") · \(display.width)×\(display.height)"
    }

    func refresh() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            self.content = content
            displays = content.displays
            if selectedDisplay == nil {
                selectedDisplayID = displays.first { $0.displayID == CGMainDisplayID() }?.displayID ?? displays.first?.displayID
            }
            let withWindows = Set(content.windows
                .filter { $0.isOnScreen && $0.windowLayer == 0 }
                .compactMap { $0.owningApplication?.bundleIdentifier })
            apps = content.applications
                .filter { $0.bundleIdentifier != ownBundleID && withWindows.contains($0.bundleIdentifier) && !$0.applicationName.isEmpty }
                .map { AppItem(id: $0.bundleIdentifier,
                               name: $0.applicationName,
                               icon: NSRunningApplication(processIdentifier: $0.processID)?.icon) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            errorMessage = nil
        } catch {
            errorMessage = "Allow Clearview in System Settings › Privacy & Security › Screen & System Audio Recording, then reopen it."
        }
    }

    func start() async {
        await refresh()
        guard let filter = makeFilter() else { return }

        let scale = CGFloat(filter.pointPixelScale)
        let config = SCStreamConfiguration()
        config.width = Int(filter.contentRect.width * scale)
        config.height = Int(filter.contentRect.height * scale)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.colorSpaceName = CGColorSpace.sRGB
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.queueDepth = 5
        config.showsCursor = true

        do {
            let stream = SCStream(filter: filter, configuration: config, delegate: delegate)
            try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: output.queue)
            try await stream.startCapture()
            self.stream = stream
            frameSize = CGSize(width: config.width, height: config.height)
            isSharing = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stop() async {
        try? await stream?.stopCapture()
        stream = nil
        isSharing = false
        frames.clear()
    }

    func setHidden(_ bundleID: String, _ hidden: Bool) {
        if hidden {
            hiddenBundleIDs.insert(bundleID)
        } else {
            hiddenBundleIDs.remove(bundleID)
        }
        Task { await applyFilter() }
    }

    func selectDisplay(_ id: CGDirectDisplayID) {
        selectedDisplayID = id
        guard isSharing else { return }
        Task {
            await stop()
            await start()
        }
    }

    private func applyFilter() async {
        guard let stream else { return }
        await refresh()
        guard let filter = makeFilter() else { return }
        try? await stream.updateContentFilter(filter)
    }

    /// Shares the chosen display minus the hidden apps. Clearview's own
    /// windows are always left out so the viewer never captures itself.
    private func makeFilter() -> SCContentFilter? {
        guard let content, let display = selectedDisplay else { return nil }
        let excluded = content.applications.filter {
            hiddenBundleIDs.contains($0.bundleIdentifier) || $0.bundleIdentifier == ownBundleID
        }
        return SCContentFilter(display: display, excludingApplications: excluded, exceptingWindows: [])
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
