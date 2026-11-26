import CoreGraphics
import Metal
import QuartzCore
import SwiftUI
import UIKit

enum OneTapeBodyShaderProgram: Hashable {
    case graphite
    case holoFoil
    case silverFoil
    case disco
    case stealthCamo
    case digitalCamo
    case circuitGlow
    case seeThrough
    case directionalRelief

    var fragmentFunctionName: String {
        switch self {
        case .graphite: "graphiteFragment"
        case .holoFoil: "holoFoilFragment"
        case .silverFoil: "silverFoilFragment"
        case .disco: "discoFragment"
        case .stealthCamo: "stealthCamoFragment"
        case .digitalCamo: "digitalCamoFragment"
        case .circuitGlow: "circuitBodyFragment"
        case .seeThrough: "seeThroughFragment"
        case .directionalRelief: "directionalReliefFragment"
        }
    }
}

struct OneTapeBodyUniforms {
    var designSize: SIMD2<Float>
    var uvOffset: SIMD2<Float>
    var uvScale: SIMD2<Float>
    var tilt: SIMD2<Float>
    var phase: Float
    var energy: Float
    var grain: Float
    var reserved: Float = 0
}

/// Shared Metal GPU renderer for body surfaces and offscreen customization previews.
/// Holds a single `MTLDevice`, command queue, compiled pipelines, and cached baked
/// CoreGraphics textures so live tilt/pulse frames perform zero CPU rasterization.
@MainActor
final class OneTapeBodyMetalEngine {
    static let shared = OneTapeBodyMetalEngine()

    let device: MTLDevice?
    private let commandQueue: MTLCommandQueue?
    private let library: MTLLibrary?
    private var pipelines: [OneTapeBodyShaderProgram: MTLRenderPipelineState] = [:]
    private var textures: [String: MTLTexture] = [:]
    private var snapshots: [String: UIImage] = [:]
    private var fallbackTexture: MTLTexture?

    private init() {
        let dev = MTLCreateSystemDefaultDevice()
        self.device = dev
        self.commandQueue = dev?.makeCommandQueue()
        if let dev {
            self.library = try? dev.makeLibrary(source: OneTapeBodyShaderSource.msl, options: nil)
            self.fallbackTexture = Self.makePlaceholderTexture(device: dev)
        } else {
            self.library = nil
        }
    }

    func pipeline(for program: OneTapeBodyShaderProgram) -> MTLRenderPipelineState? {
        if let cached = pipelines[program] { return cached }
        guard let device, let library,
              let vertexFn = library.makeFunction(name: "bodyFullscreenVertex"),
              let fragmentFn = library.makeFunction(name: program.fragmentFunctionName) else {
            return nil
        }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFn
        descriptor.fragmentFunction = fragmentFn
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        guard let state = try? device.makeRenderPipelineState(descriptor: descriptor) else {
            return nil
        }
        pipelines[program] = state
        return state
    }

    /// Lazily bakes a deterministic CoreGraphics texture (at 2x 393×852 = 786×1704)
    /// once per key and uploads it to GPU memory for fast fragment shader sampling.
    func cachedTexture(
        key: String,
        size: CGSize = CGSize(width: 393, height: 852),
        scale: CGFloat = 2.0,
        draw: (CGContext, CGRect) -> Void
    ) -> MTLTexture? {
        if let existing = textures[key] { return existing }
        guard let device else { return nil }
        let pixelWidth = max(1, Int(round(size.width * scale)))
        let pixelHeight = max(1, Int(round(size.height * scale)))
        let bytesPerRow = pixelWidth * 4
        var buffer = [UInt8](repeating: 0, count: bytesPerRow * pixelHeight)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        let drawn: Bool = buffer.withUnsafeMutableBytes { raw in
            guard let baseAddress = raw.baseAddress,
                  let ctx = CGContext(
                    data: baseAddress,
                    width: pixelWidth,
                    height: pixelHeight,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: colorSpace,
                    bitmapInfo: bitmapInfo
                  ) else { return false }
            // Flip to SwiftUI top-left logical design coordinates (393×852).
            ctx.translateBy(x: 0, y: CGFloat(pixelHeight))
            ctx.scaleBy(x: scale, y: -scale)
            draw(ctx, CGRect(origin: .zero, size: size))
            return true
        }
        guard drawn else { return nil }
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: pixelWidth,
            height: pixelHeight,
            mipmapped: false
        )
        desc.usage = [.shaderRead]
        guard let tex = device.makeTexture(descriptor: desc) else { return nil }
        buffer.withUnsafeBytes { raw in
            if let base = raw.baseAddress {
                tex.replace(
                    region: MTLRegionMake2D(0, 0, pixelWidth, pixelHeight),
                    mipmapLevel: 0,
                    withBytes: base,
                    bytesPerRow: bytesPerRow
                )
            }
        }
        textures[key] = tex
        return tex
    }

    func render(
        to layer: CAMetalLayer,
        program: OneTapeBodyShaderProgram,
        uniforms: OneTapeBodyUniforms,
        texture0: MTLTexture? = nil,
        texture1: MTLTexture? = nil
    ) {
        guard let queue = commandQueue,
              let state = pipeline(for: program),
              let drawable = layer.nextDrawable(),
              let commandBuffer = queue.makeCommandBuffer() else { return }

        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = drawable.texture
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return }
        encodeQuad(encoder: encoder, state: state, uniforms: uniforms, texture0: texture0, texture1: texture1)
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    /// Renders a cached offscreen UIImage snapshot of a Metal body program (used by
    /// `OneTapeMaterialPreview` thumbnails so scrolling stays 120fps without spawning
    /// multiple live `CAMetalLayer` hosts).
    func cachedSnapshot(
        key: String,
        program: OneTapeBodyShaderProgram,
        pixelSize: CGSize,
        uniforms: OneTapeBodyUniforms,
        texture0: MTLTexture? = nil,
        texture1: MTLTexture? = nil
    ) -> UIImage? {
        if let cached = snapshots[key] { return cached }
        guard let device, let queue = commandQueue,
              let state = pipeline(for: program) else { return nil }

        let width = max(1, Int(round(pixelSize.width)))
        let height = max(1, Int(round(pixelSize.height)))
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        desc.usage = [.renderTarget, .shaderRead]
        desc.storageMode = .shared
        guard let target = device.makeTexture(descriptor: desc),
              let commandBuffer = queue.makeCommandBuffer() else { return nil }

        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return nil }
        encodeQuad(encoder: encoder, state: state, uniforms: uniforms, texture0: texture0, texture1: texture1)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        let bytesPerRow = width * 4
        var bytes = [UInt8](repeating: 0, count: bytesPerRow * height)
        target.getBytes(&bytes, bytesPerRow: bytesPerRow,
                        from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else { return nil }

        let image = UIImage(cgImage: cgImage, scale: 2.0, orientation: .up)
        snapshots[key] = image
        return image
    }

    private func encodeQuad(
        encoder: MTLRenderCommandEncoder,
        state: MTLRenderPipelineState,
        uniforms: OneTapeBodyUniforms,
        texture0: MTLTexture?,
        texture1: MTLTexture?
    ) {
        var u = uniforms
        encoder.setRenderPipelineState(state)
        encoder.setFragmentBytes(&u, length: MemoryLayout<OneTapeBodyUniforms>.stride, index: 0)
        if let t0 = texture0 ?? fallbackTexture {
            encoder.setFragmentTexture(t0, index: 0)
        }
        if let t1 = texture1 ?? fallbackTexture {
            encoder.setFragmentTexture(t1, index: 1)
        }
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    }

    private static func makePlaceholderTexture(device: MTLDevice) -> MTLTexture? {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: 1, height: 1, mipmapped: false
        )
        desc.usage = [.shaderRead]
        guard let tex = device.makeTexture(descriptor: desc) else { return nil }
        var pixel: [UInt8] = [0, 0, 0, 0]
        tex.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: &pixel, bytesPerRow: 4)
        return tex
    }
}

/// Lightweight `CAMetalLayer`-backed view that redraws only when shader inputs change,
/// or via an internal GPU-only `CADisplayLink` when `animatePulse` is enabled (keeping
/// SwiftUI layout/masking completely idle at 60fps during circuit pulse animation).
struct OneTapeMetalBodyView: UIViewRepresentable {
    let program: OneTapeBodyShaderProgram
    let tilt: CGSize
    var energy: Double = 0
    var animatePulse: Bool = false
    var grain: Double = 0.018
    var texture0: MTLTexture? = nil
    var texture1: MTLTexture? = nil

    func makeUIView(context: Context) -> MetalBodyHostView {
        let view = MetalBodyHostView()
        view.isUserInteractionEnabled = false
        view.isOpaque = true
        return view
    }

    func updateUIView(_ uiView: MetalBodyHostView, context: Context) {
        uiView.configure(
            program: program,
            tilt: tilt,
            energy: energy,
            animatePulse: animatePulse,
            grain: grain,
            texture0: texture0,
            texture1: texture1
        )
    }

    static func dismantleUIView(_ uiView: MetalBodyHostView, coordinator: ()) {
        uiView.stopDisplayLink()
    }
}

final class MetalBodyHostView: UIView {
    override class var layerClass: AnyClass { CAMetalLayer.self }

    private var metalLayer: CAMetalLayer { layer as! CAMetalLayer }
    private var lastProgram: OneTapeBodyShaderProgram?
    private var lastTilt: CGSize = .zero
    private var lastEnergy: Double = 0
    private var lastGrain: Double = 0.018
    private var lastTexture0: MTLTexture?
    private var lastTexture1: MTLTexture?
    private var animatePulse = false
    private var displayLink: CADisplayLink?
    private var startTimestamp: CFTimeInterval = CACurrentMediaTime()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLayer()
    }

    deinit {
        displayLink?.invalidate()
    }

    private func configureLayer() {
        metalLayer.device = OneTapeBodyMetalEngine.shared.device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
        metalLayer.presentsWithTransaction = false
        metalLayer.isOpaque = true
        metalLayer.contentsScale = 2.0
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        syncDisplayLink()
        if window != nil {
            drawCurrentFrame(phase: currentPhase)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let scale = metalLayer.contentsScale
        let target = CGSize(width: max(1, bounds.width * scale), height: max(1, bounds.height * scale))
        if metalLayer.drawableSize != target {
            metalLayer.drawableSize = target
            drawCurrentFrame(phase: currentPhase)
        }
    }

    func configure(
        program: OneTapeBodyShaderProgram,
        tilt: CGSize,
        energy: Double,
        animatePulse: Bool,
        grain: Double,
        texture0: MTLTexture?,
        texture1: MTLTexture?
    ) {
        self.lastProgram = program
        self.lastTilt = tilt
        self.lastEnergy = energy
        self.lastGrain = grain
        self.lastTexture0 = texture0
        self.lastTexture1 = texture1
        self.animatePulse = animatePulse
        syncDisplayLink()
        drawCurrentFrame(phase: currentPhase)
    }

    func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    private var currentPhase: Float {
        animatePulse ? Float(CACurrentMediaTime() - startTimestamp) : 0.25
    }

    private func syncDisplayLink() {
        let shouldRun = animatePulse && window != nil
        if shouldRun {
            if displayLink == nil {
                startTimestamp = CACurrentMediaTime()
                let link = CADisplayLink(target: self, selector: #selector(handleDisplayLink))
                link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
                link.add(to: .main, forMode: .common)
                displayLink = link
            }
        } else {
            stopDisplayLink()
        }
    }

    @objc private func handleDisplayLink() {
        drawCurrentFrame(phase: currentPhase)
    }

    private func drawCurrentFrame(phase: Float) {
        guard let program = lastProgram, bounds.width > 0, bounds.height > 0 else { return }
        let scale = metalLayer.contentsScale
        let target = CGSize(width: max(1, bounds.width * scale), height: max(1, bounds.height * scale))
        if metalLayer.drawableSize != target {
            metalLayer.drawableSize = target
        }
        let uniforms = OneTapeBodyUniforms(
            designSize: SIMD2(393, 852),
            uvOffset: .zero,
            uvScale: SIMD2(1, 1),
            tilt: SIMD2(Float(lastTilt.width), Float(lastTilt.height)),
            phase: phase,
            energy: Float(min(1, max(0, lastEnergy))),
            grain: Float(lastGrain)
        )
        OneTapeBodyMetalEngine.shared.render(
            to: metalLayer,
            program: program,
            uniforms: uniforms,
            texture0: lastTexture0,
            texture1: lastTexture1
        )
    }
}
