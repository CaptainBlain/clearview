import MetalKit
import SwiftUI

/// Shows the newest captured frame with Metal. Frames come straight from
/// ScreenCaptureKit's IOSurface-backed buffers wrapped as a Metal texture, so
/// nothing is copied on the CPU.
struct FrameView: NSViewRepresentable {
    let frames: FrameReceiver

    func makeCoordinator() -> FrameRenderer {
        FrameRenderer(frames: frames)
    }

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: context.coordinator.device)
        view.colorPixelFormat = .bgra8Unorm
        view.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        view.clearColor = MTLClearColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.framebufferOnly = true
        view.delegate = context.coordinator
        return view
    }

    func updateNSView(_ view: MTKView, context: Context) {}
}

final class FrameRenderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    private let frames: FrameReceiver
    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private let sampler: MTLSamplerState

    init(frames: FrameReceiver) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary()
        else { fatalError("Metal is unavailable") }
        self.device = device
        self.frames = frames
        self.queue = queue

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "quadVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "quadFragment")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipeline = try! device.makeRenderPipelineState(descriptor: descriptor)

        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        sampler = device.makeSamplerState(descriptor: samplerDescriptor)!

        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let pass = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let commands = queue.makeCommandBuffer(),
              let encoder = commands.makeRenderCommandEncoder(descriptor: pass)
        else { return }

        if let frame = frames.latest,
           let surface = CVPixelBufferGetIOSurface(frame)?.takeUnretainedValue() {
            let width = CVPixelBufferGetWidth(frame)
            let height = CVPixelBufferGetHeight(frame)
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
            descriptor.usage = .shaderRead
            descriptor.storageMode = .shared
            if let texture = device.makeTexture(descriptor: descriptor, iosurface: surface, plane: 0) {
                let drawableSize = view.drawableSize
                let fit = Geometry.aspectFit(CGSize(width: width, height: height),
                                             in: CGRect(origin: .zero, size: drawableSize))
                var rect = SIMD4<Float>(Float(fit.minX / drawableSize.width * 2 - 1),
                                        Float(1 - fit.maxY / drawableSize.height * 2),
                                        Float(fit.maxX / drawableSize.width * 2 - 1),
                                        Float(1 - fit.minY / drawableSize.height * 2))
                encoder.setRenderPipelineState(pipeline)
                encoder.setVertexBytes(&rect, length: MemoryLayout<SIMD4<Float>>.size, index: 0)
                encoder.setFragmentTexture(texture, index: 0)
                encoder.setFragmentSamplerState(sampler, index: 0)
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            }
            // Keep the frame's buffer alive until the GPU has finished with it.
            commands.addCompletedHandler { _ in _ = frame }
        }
        encoder.endEncoding()
        commands.present(drawable)
        commands.commit()
    }
}
