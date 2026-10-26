import MetalKit
import SwiftUI

/// Shows the newest captured frame with Metal. Frames come straight from
/// ScreenCaptureKit's IOSurface-backed buffers through a texture cache, so
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

/// The quad shader, compiled at launch so the project builds without the
/// separate Metal toolchain download. rect is (left, bottom, right, top) in
/// clip space.
private let shaderSource = """
#include <metal_stdlib>
using namespace metal;

struct QuadOut {
    float4 position [[position]];
    float2 uv;
};

vertex QuadOut quadVertex(uint vid [[vertex_id]], constant float4 &rect [[buffer(0)]]) {
    float2 uv = float2(vid & 1, vid >> 1);
    QuadOut out;
    out.position = float4(mix(rect.x, rect.z, uv.x), mix(rect.w, rect.y, uv.y), 0, 1);
    out.uv = uv;
    return out;
}

fragment float4 quadFragment(QuadOut in [[stage_in]],
                             texture2d<float> frame [[texture(0)]],
                             sampler linear [[sampler(0)]]) {
    return frame.sample(linear, in.uv);
}
"""

final class FrameRenderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    private let frames: FrameReceiver
    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private let sampler: MTLSamplerState
    private var textureCache: CVMetalTextureCache?

    init(frames: FrameReceiver) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue(),
              let library = try? device.makeLibrary(source: shaderSource, options: nil)
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

        CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)
        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let pass = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let commands = queue.makeCommandBuffer(),
              let encoder = commands.makeRenderCommandEncoder(descriptor: pass)
        else { return }

        var cvTexture: CVMetalTexture?
        if let frame = frames.latest, let textureCache {
            let width = CVPixelBufferGetWidth(frame)
            let height = CVPixelBufferGetHeight(frame)
            CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, frame, nil, .bgra8Unorm, width, height, 0, &cvTexture)
            if let cvTexture, let texture = CVMetalTextureGetTexture(cvTexture) {
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
        }
        encoder.endEncoding()
        commands.present(drawable)
        // Keep the CoreVideo texture alive until the GPU has finished with it.
        commands.addCompletedHandler { _ in _ = cvTexture }
        commands.commit()
    }
}
