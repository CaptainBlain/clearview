import CoreVideo
import QuartzCore
import ScreenCaptureKit

/// Receives frames from the stream and keeps the newest one for the renderer,
/// counting frames per second. Written on the capture queue, read on the
/// render thread.
final class FrameReceiver: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    let queue = DispatchQueue(label: "clearview.frames", qos: .userInteractive)
    var onStop: (Error) -> Void = { _ in }

    private let lock = NSLock()
    private var latestFrame: CVPixelBuffer?
    private var arrivals: [CFTimeInterval] = []

    var latest: CVPixelBuffer? {
        lock.withLock { latestFrame }
    }

    /// Frames delivered in the last second. ScreenCaptureKit only sends a
    /// frame when something on screen changes, so a still screen reads low.
    var framesPerSecond: Int {
        lock.withLock {
            let now = CACurrentMediaTime()
            return arrivals.filter { now - $0 <= 1 }.count
        }
    }

    func clear() {
        lock.withLock {
            latestFrame = nil
            arrivals.removeAll()
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              sampleBuffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let rawStatus = attachments.first?[.status] as? Int,
              SCFrameStatus(rawValue: rawStatus) == .complete,
              let frame = sampleBuffer.imageBuffer
        else { return }
        lock.withLock {
            latestFrame = frame
            let now = CACurrentMediaTime()
            arrivals.append(now)
            arrivals.removeAll { now - $0 > 1 }
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        onStop(error)
    }
}
