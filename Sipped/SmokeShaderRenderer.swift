import MetalKit
import SwiftUI

struct SmokeShaderBackground: UIViewRepresentable {
    let runsAnimation: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero)
        view.backgroundColor = UIColor(red: 3 / 255, green: 28 / 255, blue: 38 / 255, alpha: 1)
        view.isOpaque = true
        view.framebufferOnly = true
        view.colorPixelFormat = .bgra8Unorm
        view.preferredFramesPerSecond = 60
        view.contentScaleFactor = min(context.environment.displayScale, 2)

        guard let device = MTLCreateSystemDefaultDevice(),
              let renderer = SmokeShaderRenderer(device: device)
        else {
            return view
        }

        view.device = device
        view.delegate = renderer
        context.coordinator.renderer = renderer
        updatePauseState(of: view)
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
        updatePauseState(of: view)
    }

    private func updatePauseState(of view: MTKView) {
        view.enableSetNeedsDisplay = !runsAnimation
        view.isPaused = !runsAnimation
        if !runsAnimation {
            view.setNeedsDisplay()
        }
    }

    final class Coordinator {
        fileprivate var renderer: SmokeShaderRenderer?
    }
}

private final class SmokeShaderRenderer: NSObject, MTKViewDelegate {
    private let commandQueue: any MTLCommandQueue
    private let pipeline: any MTLRenderPipelineState
    private let startTime = CACurrentMediaTime()
    private var packedUniforms: [SIMD4<Float>] = [
        SIMD4(0.012, 0.110, 0.149, 0),
        SIMD4(0.106, 0.424, 0.659, 0),
        SIMD4(0.353, 0.824, 0.957, 0),
        SIMD4(0.918, 0.976, 1.000, 0),
        .zero, .zero, .zero, .zero,
        .zero,
        SIMD4(1.72, 0.60, 0.50, 0),
        SIMD4(2.40, 1.22, 0, 1),
        SIMD4(0, 0, 0, 0),
        SIMD4(635, 0, 0, 0),
        SIMD4(0, 0, 0, 0),
        SIMD4(0, 2, 0.65, 0.46)
    ]

    init?(device: any MTLDevice) {
        guard let commandQueue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary(),
              let vertexFunction = library.makeFunction(name: "sippedSmokeVertex"),
              let fragmentFunction = library.makeFunction(name: "sippedSmokeFragment")
        else {
            return nil
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        guard let pipeline = try? device.makeRenderPipelineState(descriptor: descriptor) else {
            return nil
        }

        self.commandQueue = commandQueue
        self.pipeline = pipeline
        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard view.drawableSize.width > 0,
              view.drawableSize.height > 0,
              let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else {
            return
        }

        let seconds = view.isPaused ? 0 : Float(CACurrentMediaTime() - startTime)
        packedUniforms[8] = SIMD4(
            Float(view.drawableSize.width),
            Float(view.drawableSize.height),
            seconds * 0.97,
            4
        )

        encoder.setRenderPipelineState(pipeline)
        packedUniforms.withUnsafeBytes { bytes in
            guard let address = bytes.baseAddress else { return }
            encoder.setFragmentBytes(address, length: bytes.count, index: 0)
        }
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
