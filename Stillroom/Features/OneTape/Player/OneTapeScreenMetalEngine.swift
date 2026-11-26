import CoreGraphics
import Metal
import QuartzCore
import SwiftUI
import UIKit

enum OneTapeScreenShaderProgram: Hashable {
    case oscilloscope
    case fluid
    case water
    case sand
    case dunes
    case iron
    case name

    init?(style: OneTapeAppearance.ScreenStyle) {
        switch style {
        case .oscilloscope: self = .oscilloscope
        case .fluid: self = .fluid
        case .water: self = .water
        case .sand: self = .sand
        case .dunes: self = .dunes
        case .iron: self = .iron
        case .name: self = .name
        default: return nil
        }
    }
}

/// Exact 96-byte layout matching `ScreenUniforms` in `OneTapeScreenShaderSource.msl`.
struct OneTapeScreenUniforms {
    var bgColor: SIMD4<Float>
    var inkColor: SIMD4<Float>
    var size: SIMD2<Float>
    var time: Float
    var scopeGain: Float
    var bass: Float
    var mid: Float
    var high: Float
    var kick: Float
    var rms: Float
    var hasSignal: Float
    var pieceCount: Int32
    var pixelScale: Float
    var gridW: Int32
    var gridH: Int32
    var pad0: Float = 0
    var pad1: Float = 0
}

/// Shared Metal GPU engine for all reflective monochrome LCD visual screens.
/// Compiles shaders once at runtime and caches render pipeline states.
@MainActor
final class OneTapeScreenMetalEngine {
    static let shared = OneTapeScreenMetalEngine()

    let device: MTLDevice?
    private let commandQueue: MTLCommandQueue?
    private let library: MTLLibrary?
    private var scopePipeline: MTLRenderPipelineState?
    private var liquidPipeline: MTLRenderPipelineState?
    private var waterPipeline: MTLRenderPipelineState?
    private var backdropPipeline: MTLRenderPipelineState?
    private var particlePipeline: MTLRenderPipelineState?
    private var ironPipeline: MTLRenderPipelineState?

    private init() {
        let dev = MTLCreateSystemDefaultDevice()
        self.device = dev
        self.commandQueue = dev?.makeCommandQueue()
        if let dev {
            do {
                self.library = try dev.makeLibrary(source: OneTapeScreenShaderSource.msl, options: nil)
            } catch {
                #if DEBUG
                print("[OneTapeScreenMetalEngine] MSL compile failed: \(error)")
                #endif
                self.library = nil
            }
        } else {
            self.library = nil
        }
    }

    private func makeFullscreenPipeline(fragmentName: String) -> MTLRenderPipelineState? {
        guard let device, let library,
              let vFn = library.makeFunction(name: "screenFullscreenVertex"),
              let fFn = library.makeFunction(name: fragmentName) else { return nil }
        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = vFn
        desc.fragmentFunction = fFn
        desc.colorAttachments[0].pixelFormat = .bgra8Unorm
        return try? device.makeRenderPipelineState(descriptor: desc)
    }

    private func makeBlendedPipeline(vertexName: String, fragmentName: String) -> MTLRenderPipelineState? {
        guard let device, let library,
              let vFn = library.makeFunction(name: vertexName),
              let fFn = library.makeFunction(name: fragmentName) else { return nil }
        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = vFn
        desc.fragmentFunction = fFn
        let att = desc.colorAttachments[0]!
        att.pixelFormat = .bgra8Unorm
        att.isBlendingEnabled = true
        att.rgbBlendOperation = .add
        att.alphaBlendOperation = .add
        att.sourceRGBBlendFactor = .sourceAlpha
        att.destinationRGBBlendFactor = .oneMinusSourceAlpha
        att.sourceAlphaBlendFactor = .one
        att.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        return try? device.makeRenderPipelineState(descriptor: desc)
    }

    private func ensurePipelines() {
        if scopePipeline == nil { scopePipeline = makeFullscreenPipeline(fragmentName: "scopeScreenFragment") }
        if liquidPipeline == nil { liquidPipeline = makeFullscreenPipeline(fragmentName: "liquidScreenFragment") }
        if waterPipeline == nil { waterPipeline = makeFullscreenPipeline(fragmentName: "waterScreenFragment") }
        if backdropPipeline == nil { backdropPipeline = makeFullscreenPipeline(fragmentName: "lcdBackdropFragment") }
        if particlePipeline == nil {
            particlePipeline = makeBlendedPipeline(vertexName: "sandParticleVertex", fragmentName: "sandParticleFragment")
        }
        if ironPipeline == nil {
            ironPipeline = makeBlendedPipeline(vertexName: "ironFilingVertex", fragmentName: "ironFilingFragment")
        }
    }

    func makeRingBuffers(byteLength: Int, slots: Int = 3) -> [MTLBuffer] {
        guard let device else { return [] }
        let len = max(64, byteLength)
        return (0..<slots).compactMap { _ in
            device.makeBuffer(length: len, options: .storageModeShared)
        }
    }

    func renderScope(to layer: CAMetalLayer, uniforms: OneTapeScreenUniforms, waveform: [Float]) {
        ensurePipelines()
        guard let queue = commandQueue, let state = scopePipeline,
              let drawable = layer.nextDrawable(), let cmd = queue.makeCommandBuffer() else { return }
        let pass = Self.makePass(texture: drawable.texture)
        guard let enc = cmd.makeRenderCommandEncoder(descriptor: pass) else { return }
        var u = uniforms
        enc.setRenderPipelineState(state)
        enc.setFragmentBytes(&u, length: MemoryLayout<OneTapeScreenUniforms>.stride, index: 0)
        waveform.withUnsafeBytes { raw in
            if let base = raw.baseAddress, raw.count >= 48 * MemoryLayout<Float>.stride {
                enc.setFragmentBytes(base, length: 48 * MemoryLayout<Float>.stride, index: 1)
            }
        }
        enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        enc.endEncoding()
        cmd.present(drawable)
        cmd.commit()
    }

    func renderLiquid(to layer: CAMetalLayer, uniforms: OneTapeScreenUniforms, pieces: [SIMD4<Float>]) {
        ensurePipelines()
        guard let queue = commandQueue, let state = liquidPipeline,
              let drawable = layer.nextDrawable(), let cmd = queue.makeCommandBuffer() else { return }
        let pass = Self.makePass(texture: drawable.texture)
        guard let enc = cmd.makeRenderCommandEncoder(descriptor: pass) else { return }
        var u = uniforms
        enc.setRenderPipelineState(state)
        enc.setFragmentBytes(&u, length: MemoryLayout<OneTapeScreenUniforms>.stride, index: 0)
        pieces.withUnsafeBytes { raw in
            if let base = raw.baseAddress, raw.count > 0 {
                enc.setFragmentBytes(base, length: raw.count, index: 2)
            }
        }
        enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        enc.endEncoding()
        cmd.present(drawable)
        cmd.commit()
    }

    func renderWater(
        to layer: CAMetalLayer,
        uniforms: OneTapeScreenUniforms,
        heightfield: [Float],
        buffer: MTLBuffer
    ) {
        ensurePipelines()
        guard let queue = commandQueue, let state = waterPipeline,
              let drawable = layer.nextDrawable(), let cmd = queue.makeCommandBuffer() else { return }
        let bytes = min(heightfield.count * MemoryLayout<Float>.stride, buffer.length)
        if bytes > 0 {
            heightfield.withUnsafeBytes { raw in
                if let src = raw.baseAddress { memcpy(buffer.contents(), src, bytes) }
            }
        }
        let pass = Self.makePass(texture: drawable.texture)
        guard let enc = cmd.makeRenderCommandEncoder(descriptor: pass) else { return }
        var u = uniforms
        enc.setRenderPipelineState(state)
        enc.setFragmentBytes(&u, length: MemoryLayout<OneTapeScreenUniforms>.stride, index: 0)
        enc.setFragmentBuffer(buffer, offset: 0, index: 1)
        enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        enc.endEncoding()
        cmd.present(drawable)
        cmd.commit()
    }

    func renderParticles(
        to layer: CAMetalLayer,
        uniforms: OneTapeScreenUniforms,
        grains: [OneTapeGPUGrain],
        buffer: MTLBuffer
    ) {
        ensurePipelines()
        guard let queue = commandQueue, let bgState = backdropPipeline, let ptState = particlePipeline,
              let drawable = layer.nextDrawable(), let cmd = queue.makeCommandBuffer() else { return }

        let count = min(grains.count, buffer.length / MemoryLayout<OneTapeGPUGrain>.stride)
        if count > 0 {
            grains.withUnsafeBytes { raw in
                if let src = raw.baseAddress {
                    memcpy(buffer.contents(), src, count * MemoryLayout<OneTapeGPUGrain>.stride)
                }
            }
        }

        let pass = Self.makePass(texture: drawable.texture)
        guard let enc = cmd.makeRenderCommandEncoder(descriptor: pass) else { return }
        var u = uniforms

        enc.setRenderPipelineState(bgState)
        enc.setFragmentBytes(&u, length: MemoryLayout<OneTapeScreenUniforms>.stride, index: 0)
        enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)

        if count > 0 {
            enc.setRenderPipelineState(ptState)
            enc.setVertexBytes(&u, length: MemoryLayout<OneTapeScreenUniforms>.stride, index: 0)
            enc.setVertexBuffer(buffer, offset: 0, index: 1)
            enc.setFragmentBytes(&u, length: MemoryLayout<OneTapeScreenUniforms>.stride, index: 0)
            enc.drawPrimitives(type: .point, vertexStart: 0, vertexCount: count)
        }

        enc.endEncoding()
        cmd.present(drawable)
        cmd.commit()
    }

    func renderIron(
        to layer: CAMetalLayer,
        uniforms: OneTapeScreenUniforms,
        filings: [OneTapeGPUFiling],
        buffer: MTLBuffer
    ) {
        ensurePipelines()
        guard let queue = commandQueue, let bgState = backdropPipeline, let ironState = ironPipeline,
              let drawable = layer.nextDrawable(), let cmd = queue.makeCommandBuffer() else { return }

        let count = min(filings.count, buffer.length / MemoryLayout<OneTapeGPUFiling>.stride)
        if count > 0 {
            filings.withUnsafeBytes { raw in
                if let src = raw.baseAddress {
                    memcpy(buffer.contents(), src, count * MemoryLayout<OneTapeGPUFiling>.stride)
                }
            }
        }

        let pass = Self.makePass(texture: drawable.texture)
        guard let enc = cmd.makeRenderCommandEncoder(descriptor: pass) else { return }
        var u = uniforms

        enc.setRenderPipelineState(bgState)
        enc.setFragmentBytes(&u, length: MemoryLayout<OneTapeScreenUniforms>.stride, index: 0)
        enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)

        if count > 0 {
            enc.setRenderPipelineState(ironState)
            enc.setVertexBytes(&u, length: MemoryLayout<OneTapeScreenUniforms>.stride, index: 0)
            enc.setVertexBuffer(buffer, offset: 0, index: 1)
            enc.setFragmentBytes(&u, length: MemoryLayout<OneTapeScreenUniforms>.stride, index: 0)
            enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: count)
        }

        enc.endEncoding()
        cmd.present(drawable)
        cmd.commit()
    }

    private static func makePass(texture: MTLTexture) -> MTLRenderPassDescriptor {
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store
        return pass
    }
}

/// 60fps `CAMetalLayer`-backed reflective LCD screen renderer. Reads real audio frames
/// directly inside its GPU `CADisplayLink` loop so SwiftUI never re-evaluates per frame.
struct OneTapeMetalScreenView: UIViewRepresentable {
    let program: OneTapeScreenShaderProgram
    let lcdMaterial: OneTapeLCDMaterial
    let readout: OneTapePlaybackReadout
    var visualization: AudioVisualizationSignal?
    var isPreview: Bool = false
    let shouldAnimate: Bool

    func makeUIView(context: Context) -> MetalScreenHostView {
        let view = MetalScreenHostView()
        view.isUserInteractionEnabled = false
        view.isOpaque = true
        return view
    }

    func updateUIView(_ uiView: MetalScreenHostView, context: Context) {
        uiView.configure(
            program: program,
            lcdMaterial: lcdMaterial,
            readout: readout,
            visualization: visualization,
            isPreview: isPreview,
            shouldAnimate: shouldAnimate
        )
    }

    static func dismantleUIView(_ uiView: MetalScreenHostView, coordinator: ()) {
        uiView.stopDisplayLink()
    }
}

final class MetalScreenHostView: UIView {
    override class var layerClass: AnyClass { CAMetalLayer.self }

    private var metalLayer: CAMetalLayer { layer as! CAMetalLayer }
    private var program: OneTapeScreenShaderProgram = .fluid
    private var lcdMaterial: OneTapeLCDMaterial = .original
    private var readout: OneTapePlaybackReadout = .empty
    private weak var visualization: AudioVisualizationSignal?
    private var isPreview = false
    private var shouldAnimate = false

    private var envelope = OneTapeScreenAudioEnvelope()
    private var liquidSim = OneTapeLiquidSimulation()
    private var waterSim = OneTapeWaterSimulation()
    private var sandSim = OneTapeSandSimulation()
    private var dunesSim = OneTapeDunesSimulation()
    private var ironSim = OneTapeIronSimulation()
    private var nameSim = OneTapeNameSandSimulation()

    // One shared 3-slot ring buffer sized to hold the largest per-frame payload
    // (3,600 grains = 57.6 KB, well above water's 16 KB & iron's 22.4 KB).
    private var sharedRingBuffers: [MTLBuffer] = []
    private var bufferCursor = 0

    private var displayLink: CADisplayLink?
    private var lastTickTime: CFTimeInterval = 0
    private var settleRemaining: Double = 0

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
        metalLayer.device = OneTapeScreenMetalEngine.shared.device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
        metalLayer.presentsWithTransaction = false
        metalLayer.isOpaque = true
        metalLayer.contentsScale = 2.0
        let grainBytes = max(OneTapeSandSimulation.grainCount,
                             max(OneTapeDunesSimulation.grainCount, OneTapeNameSandSimulation.grainCount))
            * MemoryLayout<OneTapeGPUGrain>.stride
        let waterBytes = OneTapeWaterSimulation.cellCount * MemoryLayout<Float>.stride
        let ironBytes = OneTapeIronSimulation.filingCount * MemoryLayout<OneTapeGPUFiling>.stride
        sharedRingBuffers = OneTapeScreenMetalEngine.shared.makeRingBuffers(
            byteLength: max(grainBytes, max(waterBytes, ironBytes)),
            slots: 3
        )
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        syncDisplayLink()
        if window != nil { drawFrame(dt: 0.0) }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let scale = metalLayer.contentsScale
        let target = CGSize(width: max(1, bounds.width * scale), height: max(1, bounds.height * scale))
        if metalLayer.drawableSize != target {
            metalLayer.drawableSize = target
            if program == .name { updateNameTargets() }
            drawFrame(dt: 0.0)
        }
    }

    func configure(
        program: OneTapeScreenShaderProgram,
        lcdMaterial: OneTapeLCDMaterial,
        readout: OneTapePlaybackReadout,
        visualization: AudioVisualizationSignal?,
        isPreview: Bool,
        shouldAnimate: Bool
    ) {
        let wasPlaying = self.readout.isPlaying
        let trackChanged = self.readout.trackID != readout.trackID
            || self.readout.title != readout.title
            || self.readout.artist != readout.artist
        let programChanged = self.program != program

        self.program = program
        self.lcdMaterial = lcdMaterial
        self.readout = readout
        self.visualization = visualization
        self.isPreview = isPreview
        self.shouldAnimate = shouldAnimate

        if program == .name {
            updateNameTargets()
            if trackChanged { settleRemaining = max(settleRemaining, 1.35) }
        } else if program == .sand && trackChanged {
            sandSim.advanceMode()
            settleRemaining = max(settleRemaining, 1.35)
        }

        if wasPlaying && !readout.isPlaying {
            settleRemaining = max(settleRemaining, program == .oscilloscope ? 0.35 : 1.15)
        }

        if programChanged && !readout.isPlaying && !isPreview {
            envelope.resetAudioImmediate()
        }

        syncDisplayLink()
        drawFrame(dt: 0.0)
    }

    func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
        lastTickTime = 0
    }

    private func syncDisplayLink() {
        let active = shouldAnimate && window != nil && (readout.isPlaying || isPreview || settleRemaining > 0)
        if active {
            if displayLink == nil {
                lastTickTime = CACurrentMediaTime()
                let link = CADisplayLink(target: self, selector: #selector(handleTick))
                link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
                link.add(to: .main, forMode: .common)
                displayLink = link
            }
        } else {
            stopDisplayLink()
        }
    }

    @objc private func handleTick() {
        let now = CACurrentMediaTime()
        let dt = lastTickTime > 0 ? min(0.05, max(0.001, now - lastTickTime)) : (1.0 / 60.0)
        lastTickTime = now

        if !readout.isPlaying && !isPreview && settleRemaining > 0 {
            settleRemaining = max(0, settleRemaining - dt)
            if settleRemaining <= 0 {
                envelope.resetAudioImmediate()
                drawFrame(dt: 0.0)
                syncDisplayLink()
                return
            }
        }

        drawFrame(dt: dt)
    }

    private func updateNameTargets() {
        guard bounds.width > 1, bounds.height > 1 else { return }
        let title: String
        let artist: String
        if readout.hasTrack {
            let t = readout.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let a = readout.artist.trimmingCharacters(in: .whitespacesAndNewlines)
            title = t.isEmpty ? "未命名歌曲" : t
            artist = a
        } else {
            title = "ONE CASSETTE"
            artist = "还没有磁带"
        }
        nameSim.configure(title: title, artist: artist, logicalSize: bounds.size)
    }

    private func nextRingBuffer() -> MTLBuffer? {
        guard !sharedRingBuffers.isEmpty else { return nil }
        let buf = sharedRingBuffers[bufferCursor % sharedRingBuffers.count]
        bufferCursor &+= 1
        return buf
    }

    private func drawFrame(dt: Double) {
        guard bounds.width > 1, bounds.height > 1 else { return }
        let scale = metalLayer.contentsScale
        let target = CGSize(width: max(1, bounds.width * scale), height: max(1, bounds.height * scale))
        if metalLayer.drawableSize != target {
            metalLayer.drawableSize = target
        }

        let activelyPlaying = readout.isPlaying && !readout.isPreparing
        if dt > 0 {
            envelope.step(
                frame: visualization?.frame,
                isPlaying: activelyPlaying,
                isPreview: isPreview,
                dt: dt
            )
            switch program {
            case .oscilloscope:
                break
            case .fluid:
                liquidSim.step(dt: dt, size: bounds.size, envelope: envelope)
            case .water:
                waterSim.step(dt: dt, envelope: envelope, isPreview: isPreview)
            case .sand:
                sandSim.step(dt: dt, envelope: envelope, isPreview: isPreview)
            case .dunes:
                dunesSim.step(dt: dt, envelope: envelope, isPreview: isPreview)
            case .iron:
                ironSim.step(dt: dt, size: bounds.size, envelope: envelope, isPreview: isPreview)
            case .name:
                updateNameTargets()
                nameSim.step(dt: dt, envelope: envelope)
            }
        } else if program == .name {
            updateNameTargets()
        } else if program == .fluid {
            liquidSim.alignIfResting(size: bounds.size)
        }

        let bg = lcdMaterial.background
        let ink = lcdMaterial.ink
        let uniforms = OneTapeScreenUniforms(
            bgColor: SIMD4(Float(bg.red), Float(bg.green), Float(bg.blue), 1),
            inkColor: SIMD4(Float(ink.red), Float(ink.green), Float(ink.blue), activelyPlaying ? 1 : 0),
            size: SIMD2(Float(bounds.width), Float(bounds.height)),
            time: envelope.time,
            scopeGain: envelope.scopeGain,
            bass: envelope.bass,
            mid: envelope.mid,
            high: envelope.high,
            kick: envelope.kick,
            rms: envelope.rms,
            hasSignal: envelope.hasSignal,
            pieceCount: Int32(OneTapeLiquidSimulation.pieceCount),
            pixelScale: Float(scale),
            gridW: Int32(OneTapeWaterSimulation.gridW),
            gridH: Int32(OneTapeWaterSimulation.gridH)
        )

        let engine = OneTapeScreenMetalEngine.shared
        switch program {
        case .oscilloscope:
            engine.renderScope(to: metalLayer, uniforms: uniforms, waveform: envelope.waveform)
        case .fluid:
            engine.renderLiquid(to: metalLayer, uniforms: uniforms, pieces: liquidSim.gpuPieces)
        case .water:
            if let buf = nextRingBuffer() {
                engine.renderWater(to: metalLayer, uniforms: uniforms, heightfield: waterSim.heightfield, buffer: buf)
            }
        case .sand:
            if let buf = nextRingBuffer() {
                engine.renderParticles(to: metalLayer, uniforms: uniforms, grains: sandSim.gpuGrains, buffer: buf)
            }
        case .dunes:
            if let buf = nextRingBuffer() {
                engine.renderParticles(to: metalLayer, uniforms: uniforms, grains: dunesSim.gpuGrains, buffer: buf)
            }
        case .iron:
            if let buf = nextRingBuffer() {
                engine.renderIron(to: metalLayer, uniforms: uniforms, filings: ironSim.gpuFilings, buffer: buf)
            }
        case .name:
            if let buf = nextRingBuffer() {
                engine.renderParticles(to: metalLayer, uniforms: uniforms, grains: nameSim.gpuGrains, buffer: buf)
            }
        }
    }
}
