import CoreGraphics
import Foundation
import simd
import UIKit

/// Packed 16-byte particle vertex sent to `sandParticleVertex` (`MTLPrimitiveType.point`).
struct OneTapeGPUGrain {
    var uv: SIMD2<Float>
    var sizePx: Float
    var shade: Float
}

/// Fast deterministic non-periodic PRNG (xorshift32) for sand particle physics and sampling.
/// Avoids floating-point modular periodicity that creates grid artifacts in shaders.
struct OneTapeFastRNG {
    private var state: UInt32

    init(seed: UInt32) {
        self.state = seed == 0 ? 0x9E37_79B9 : seed
    }

    mutating func nextUInt32() -> UInt32 {
        var x = state
        x ^= x << 13
        x ^= x >> 17
        x ^= x << 5
        state = x
        return x
    }

    mutating func nextFloat() -> Float {
        Float(nextUInt32() & 0x00FF_FFFF) / Float(0x0100_0000)
    }

    mutating func nextSigned() -> Float {
        nextFloat() * 2.0 - 1.0
    }
}

/// Real-time audio feature envelope updated inside the 60fps `CADisplayLink` tick.
/// Extracts bass/mid/high energy, one-shot beat impulses, auto-gained real PCM scope trace,
/// and smooth rest decay without causing SwiftUI view invalidations.
struct OneTapeScreenAudioEnvelope {
    var time: Float = 0
    var songPhase: Float = 0
    var bass: Float = 0
    var mid: Float = 0
    var high: Float = 0
    var kick: Float = 0
    var kickImpulse: Float = 0
    var rms: Float = 0
    var hasSignal: Float = 0
    var scopeGain: Float = 1.0
    var waveform = [Float](repeating: 0, count: 48)
    private var prevLowEnergy: Float = 0
    private var kickCooldown: Float = 0

    mutating func step(
        frame: AudioVisualizationFrame?,
        isPlaying: Bool,
        isPreview: Bool,
        dt rawDT: Double
    ) {
        let dt = Float(min(0.05, max(0.001, rawDT)))
        let activePCM = isPlaying && frame?.status == .active
        let liveFrame = activePCM ? frame : nil
        kickImpulse = 0
        kickCooldown = max(0, kickCooldown - dt)

        if let liveFrame {
            hasSignal = min(1, hasSignal + dt * 10.0)
            let b = Self.bandAverage(liveFrame.bands, range: 0..<4)
            let m = Self.bandAverage(liveFrame.bands, range: 4..<13)
            let h = Self.bandAverage(liveFrame.bands, range: 13..<24)
            let r = Self.clamp01(liveFrame.rms * 1.45)

            bass = Self.smooth(current: bass, target: b, dt: dt, attack: 26, release: 7.5)
            mid  = Self.smooth(current: mid,  target: m, dt: dt, attack: 22, release: 7.0)
            high = Self.smooth(current: high, target: h, dt: dt, attack: 28, release: 9.0)
            rms  = Self.smooth(current: rms,  target: r, dt: dt, attack: 24, release: 7.0)

            let lowNow = b * 0.72 + Self.clamp01(liveFrame.peak) * 0.28
            let delta = max(0, lowNow - prevLowEnergy)
            prevLowEnergy = prevLowEnergy * exp(-dt * 11.0) + lowNow * (1.0 - exp(-dt * 11.0))
            let onset = Self.clamp01(delta * 4.6 + max(0, liveFrame.peak - liveFrame.rms) * 1.25)
            if onset > kick {
                if onset > 0.28 && kickCooldown <= 0 {
                    kickImpulse = min(1.0, onset * 1.15)
                    kickCooldown = 0.14
                }
                kick = min(1.0, onset)
            } else {
                kick = max(0, kick * exp(-dt * 5.8))
            }

            // Gentle auto-gain for real non-silent PCM so quiet tracks trace clearly without clipping.
            let targetGain: Float
            if liveFrame.peak > 0.003 {
                targetGain = min(2.2, max(1.0, 0.62 / max(0.22, liveFrame.peak)))
            } else {
                targetGain = 1.0
            }
            scopeGain = Self.smooth(current: scopeGain, target: targetGain, dt: dt, attack: 8, release: 3.5)

            let src = liveFrame.waveform
            let alpha = min(1, dt * 42.0)
            for i in 0..<48 {
                let sample = i < src.count && src[i].isFinite ? max(-1, min(1, src[i])) : 0
                waveform[i] += (sample - waveform[i]) * alpha
            }

            time += dt * (0.9 + rms * 1.1)
            songPhase += dt * (0.45 + rms * 1.35)
        } else {
            hasSignal = max(0, hasSignal - dt * 7.5)
            let decay = exp(-dt * 8.0)
            bass *= decay
            mid  *= decay
            high *= decay
            kick *= decay
            rms  *= decay
            prevLowEnergy *= decay
            scopeGain = 1.0 + (scopeGain - 1.0) * decay
            for i in 0..<48 { waveform[i] *= decay }

            if isPlaying || isPreview {
                time += dt * 0.55
                songPhase += dt * 0.14
            }
        }
    }

    mutating func resetAudioImmediate() {
        hasSignal = 0
        bass = 0
        mid = 0
        high = 0
        kick = 0
        kickImpulse = 0
        rms = 0
        prevLowEnergy = 0
        scopeGain = 1.0
        for i in 0..<48 { waveform[i] = 0 }
    }

    private static func bandAverage(_ bands: [Float], range: Range<Int>) -> Float {
        guard !bands.isEmpty else { return 0 }
        let lo = min(bands.count, range.lowerBound)
        let hi = min(bands.count, range.upperBound)
        guard hi > lo else { return 0 }
        var sum: Float = 0
        for i in lo..<hi {
            let v = bands[i]
            if v.isFinite { sum += max(0, min(1, v)) }
        }
        return clamp01((sum / Float(hi - lo)) * 1.28)
    }

    private static func smooth(current: Float, target: Float, dt: Float, attack: Float, release: Float) -> Float {
        let rate = target > current ? attack : release
        let k = 1.0 - exp(-dt * rate)
        return current + (target - current) * k
    }

    private static func clamp01(_ x: Float) -> Float {
        x.isFinite ? max(0, min(1, x)) : 0
    }
}

/// Real-time 2D physics simulation for the black magnetic ferrofluid display.
/// Works in short-axis-normalized coordinates so portrait (`264×165`) and
/// landscape (`165×264`) stay identically proportioned and never clip against the bezel.
struct OneTapeLiquidSimulation {
    static let pieceCount = 9

    private struct Piece {
        var pos: SIMD2<Float>
        var vel: SIMD2<Float>
        var baseRadius: Float
        var phase: Float
        var orbitScale: Float
        var orbitSpeed: Float
    }

    private var pieces: [Piece] = []
    private var rng = OneTapeFastRNG(seed: 0x51C0_F1AD)
    private var hasStepped = false
    private var initializedWide = true
    private(set) var gpuPieces = [SIMD4<Float>](repeating: .zero, count: pieceCount)

    init() {
        reset(wide: true)
    }

    mutating func alignIfResting(size: CGSize) {
        guard !hasStepped, size.width > 1, size.height > 1 else { return }
        let wide = size.width >= size.height
        if wide != initializedWide {
            reset(wide: wide)
        }
    }

    mutating func reset(wide: Bool = true) {
        initializedWide = wide
        hasStepped = false
        // Sculpted asymmetric ferrofluid cluster: organic dual-lobe core mass,
        // three stretching neck lobes, and four crisp detached magnetic satellite beads.
        let specs: [(SIMD2<Float>, Float, Float, Float)] = [
            (SIMD2(-0.085,  0.020), 0.142, 0.06,  0.55),
            (SIMD2( 0.085, -0.030), 0.116, 0.09, -0.62),
            (SIMD2(-0.240, -0.095), 0.072, 0.25,  0.82),
            (SIMD2( 0.250,  0.085), 0.066, 0.27, -0.76),
            (SIMD2( 0.020,  0.190), 0.060, 0.22,  0.94),
            (SIMD2(-0.425,  0.125), 0.056, 0.42, -1.12),
            (SIMD2( 0.445, -0.105), 0.052, 0.44,  1.05),
            (SIMD2(-0.185, -0.265), 0.048, 0.34, -1.24),
            (SIMD2( 0.225,  0.255), 0.044, 0.36,  1.18)
        ]
        pieces = specs.enumerated().map { idx, spec in
            let p = wide ? spec.0 : SIMD2(spec.0.y, spec.0.x)
            return Piece(
                pos: p,
                vel: .zero,
                baseRadius: spec.1,
                phase: Float(idx) * 0.91 + 0.4,
                orbitScale: spec.2,
                orbitSpeed: spec.3
            )
        }
        syncGPU(bass: 0, kick: 0)
    }

    mutating func step(dt rawDT: Double, size: CGSize, envelope: OneTapeScreenAudioEnvelope) {
        hasStepped = true
        let dt = Float(min(0.033, max(0.001, rawDT)))
        let w = max(1, Float(size.width))
        let h = max(1, Float(size.height))
        let minDim = min(w, h)
        let halfW = (w / minDim) * 0.5
        let halfH = (h / minDim) * 0.5
        let isWide = w >= h
        let t = envelope.time

        // On beat onset, launch satellite droplets outward with a swirling ferrofluid split.
        if envelope.kickImpulse > 0.12 {
            let impulse = envelope.kickImpulse
            for i in 1..<pieces.count {
                let p = pieces[i].pos
                let len = simd_length(p)
                let radial: SIMD2<Float>
                if len > 0.02 {
                    radial = p / len
                } else {
                    let a = rng.nextFloat() * Float.pi * 2
                    radial = SIMD2(cos(a), sin(a))
                }
                let tangent = SIMD2(-radial.y, radial.x) * (i % 2 == 0 ? 1 : -1)
                let scale: Float = i < 5 ? 0.55 : 0.85
                pieces[i].vel += (radial * 0.85 + tangent * 0.42) * (impulse * scale)
            }
        }

        // Smooth forces: target orbital breathing + magnetic cohesion + pairwise separation + wall margin.
        for i in 0..<pieces.count {
            let fi = Float(i)
            let ang = pieces[i].phase + t * pieces[i].orbitSpeed
            let breath = 1.0 + envelope.bass * 0.36 + envelope.kick * 0.24
            let spreadX: Float = isWide ? 1.28 : 0.78
            let spreadY: Float = isWide ? 0.78 : 1.28
            let target = SIMD2<Float>(
                cos(ang) * pieces[i].orbitScale * spreadX * breath,
                sin(ang * 1.15 + fi * 0.5) * pieces[i].orbitScale * spreadY * breath
            )

            // Magnetic spring toward organic orbital equilibrium.
            let springK: Float = i < 2 ? 4.2 : (i < 5 ? 3.1 : 2.4)
            var accel = (target - pieces[i].pos) * springK

            // Gentle acoustic eddy swirl while music plays.
            if envelope.rms > 0.02 {
                let eddy = SIMD2<Float>(
                    sin(t * 1.7 + pieces[i].pos.y * 5.0 + fi),
                    cos(t * 1.5 - pieces[i].pos.x * 5.0 + fi)
                )
                accel += eddy * (envelope.mid * 0.45 + envelope.high * 0.20)
            }

            // Pairwise short-range separation prevents collapsing into a single dull blob.
            for j in 0..<pieces.count where j != i {
                let diff = pieces[i].pos - pieces[j].pos
                let distSq = simd_length_squared(diff)
                let desired = (pieces[i].baseRadius + pieces[j].baseRadius) * (i < 2 && j < 2 ? 0.90 : 1.38)
                if distSq < desired * desired && distSq > 1e-5 {
                    let dist = sqrt(distSq)
                    let push = (desired - dist) / desired
                    accel += (diff / dist) * push * 5.8
                }
            }

            // Soft glass wall repulsion keeps droplets comfortably inside the LCD bezel.
            let margin = pieces[i].baseRadius + 0.08
            let limX = max(0.08, halfW - margin)
            let limY = max(0.08, halfH - margin)
            if pieces[i].pos.x > limX { accel.x -= (pieces[i].pos.x - limX) * 28.0 }
            if pieces[i].pos.x < -limX { accel.x -= (pieces[i].pos.x + limX) * 28.0 }
            if pieces[i].pos.y > limY { accel.y -= (pieces[i].pos.y - limY) * 28.0 }
            if pieces[i].pos.y < -limY { accel.y -= (pieces[i].pos.y + limY) * 28.0 }

            pieces[i].vel += accel * dt
            pieces[i].vel *= exp(-dt * 3.1)
            pieces[i].pos += pieces[i].vel * dt
            pieces[i].pos.x = max(-limX - 0.03, min(limX + 0.03, pieces[i].pos.x))
            pieces[i].pos.y = max(-limY - 0.03, min(limY + 0.03, pieces[i].pos.y))
        }

        syncGPU(bass: envelope.bass, kick: envelope.kick)
    }

    private mutating func syncGPU(bass: Float, kick: Float) {
        for i in 0..<pieces.count {
            let swell = 1.0 + bass * (i < 2 ? 0.14 : 0.09) + kick * (i < 2 ? 0.07 : 0.11)
            gpuPieces[i] = SIMD4(
                pieces[i].pos.x,
                pieces[i].pos.y,
                pieces[i].baseRadius * swell,
                pieces[i].phase
            )
        }
    }
}

/// Real 3,600-particle Chladni acoustic sand plate simulation.
/// Grains physically migrate along analytical standing-wave gradients toward nodal curves,
/// forming lush granular sand ridges that leap off the plate on kicks and stream into new modes.
struct OneTapeSandSimulation {
    static let grainCount = 3_600

    private struct Grain {
        var x: Float      // [-1, 1] plate coords
        var y: Float
        var vx: Float
        var vy: Float
        var sizePx: Float
        var shade: Float
        var ridgeBias: Float // subtle per-grain resting offset for natural sand pile width
    }

    private static let modes: [(Float, Float)] = [
        (2, 3), (3, 5), (2, 5), (4, 3), (3, 7), (5, 4)
    ]

    private var grains: [Grain] = []
    private var rng = OneTapeFastRNG(seed: 0xC41A_D411)
    private var modeIndex: Int = 0
    private var modeTimer: Float = 0
    private(set) var gpuGrains: [OneTapeGPUGrain] = []

    init() {
        grains.reserveCapacity(Self.grainCount)
        gpuGrains = Array(repeating: OneTapeGPUGrain(uv: .zero, sizePx: 2.5, shade: 0.9), count: Self.grainCount)
        for _ in 0..<Self.grainCount {
            // Gaussian-like sum of two uniforms gives dense ridge crests with tapered granular shoulders.
            let bias = (rng.nextSigned() + rng.nextSigned()) * 0.085
            grains.append(Grain(
                x: rng.nextSigned() * 0.94,
                y: rng.nextSigned() * 0.94,
                vx: 0,
                vy: 0,
                sizePx: 2.0 + rng.nextFloat() * 1.85,
                shade: 0.68 + rng.nextFloat() * 0.30,
                ridgeBias: bias
            ))
        }
        settleInitialPattern()
        syncGPU()
    }

    mutating func advanceMode() {
        modeIndex = (modeIndex + 1) % Self.modes.count
        modeTimer = 0
        for i in 0..<grains.count {
            grains[i].vx += rng.nextSigned() * 0.72
            grains[i].vy += rng.nextSigned() * 0.72
        }
    }

    mutating func step(dt rawDT: Double, envelope: OneTapeScreenAudioEnvelope, isPreview: Bool) {
        let dt = Float(min(0.033, max(0.001, rawDT)))
        modeTimer += dt * (0.45 + envelope.rms * 1.15)
        if modeTimer > 7.5 {
            modeTimer = 0
            modeIndex = (modeIndex + 1) % Self.modes.count
        }

        let (n, m) = Self.modes[modeIndex]
        let nPi = n * Float.pi
        let mPi = m * Float.pi
        let kickBurst = envelope.kickImpulse
        let rumble = envelope.bass * 0.18 + envelope.kick * 0.30 + (isPreview ? 0.05 : 0)
        let settleGain: Float = 2.60 + envelope.mid * 0.55
        let damp = exp(-dt * 5.2)

        for i in 0..<grains.count {
            var g = grains[i]
            let nx = nPi * g.x
            let my = mPi * g.y
            let mx = mPi * g.x
            let ny = nPi * g.y

            let f = cos(nx) * cos(my) - cos(mx) * cos(ny)
            let dfdx = -nPi * sin(nx) * cos(my) + mPi * sin(mx) * cos(ny)
            let dfdy = -mPi * cos(nx) * sin(my) + nPi * cos(mx) * sin(ny)
            let invGrad = 1.0 / (hypot(dfdx, dfdy) + 1.2)

            // Settle onto `f == ridgeBias` so the sand accumulates into realistic wide granular dunes.
            let targetF = f - g.ridgeBias
            g.vx += (-targetF * dfdx * invGrad) * settleGain * dt
            g.vy += (-targetF * dfdy * invGrad) * settleGain * dt

            // Beat-triggered ballistic hop + anti-node acoustic vibration.
            if kickBurst > 0.12 {
                let hop = kickBurst * (0.45 + 0.55 * min(1.0, abs(f)))
                g.vx += rng.nextSigned() * hop * 1.75
                g.vy += rng.nextSigned() * hop * 1.75
            }
            if rumble > 0.01 {
                let vib = rumble * (0.30 + 0.70 * min(1.0, abs(f)))
                g.vx += rng.nextSigned() * vib * 4.8 * dt
                g.vy += rng.nextSigned() * vib * 4.8 * dt
            }

            g.vx *= damp
            g.vy *= damp
            g.x += g.vx * dt
            g.y += g.vy * dt

            if g.x < -0.95 { g.x = -0.95; g.vx = abs(g.vx) * 0.35 }
            else if g.x > 0.95 { g.x = 0.95; g.vx = -abs(g.vx) * 0.35 }
            if g.y < -0.95 { g.y = -0.95; g.vy = abs(g.vy) * 0.35 }
            else if g.y > 0.95 { g.y = 0.95; g.vy = -abs(g.vy) * 0.35 }

            grains[i] = g
        }

        syncGPU()
    }

    private mutating func settleInitialPattern() {
        let (n, m) = Self.modes[modeIndex]
        let nPi = n * Float.pi
        let mPi = m * Float.pi
        // Keep ~4% loose ambient stray grains resting naturally across the plate.
        let activeCount = Int(Double(grains.count) * 0.96)
        for _ in 0..<24 {
            for i in 0..<activeCount {
                var g = grains[i]
                let nx = nPi * g.x
                let my = mPi * g.y
                let mx = mPi * g.x
                let ny = nPi * g.y
                let f = (cos(nx) * cos(my) - cos(mx) * cos(ny)) - g.ridgeBias
                let dfdx = -nPi * sin(nx) * cos(my) + mPi * sin(mx) * cos(ny)
                let dfdy = -mPi * cos(nx) * sin(my) + nPi * cos(mx) * sin(ny)
                let invGrad = 1.0 / (hypot(dfdx, dfdy) + 1.1)
                g.x += (-f * dfdx * invGrad) * 0.055 + rng.nextSigned() * 0.008
                g.y += (-f * dfdy * invGrad) * 0.055 + rng.nextSigned() * 0.008
                g.x = max(-0.95, min(0.95, g.x))
                g.y = max(-0.95, min(0.95, g.y))
                grains[i] = g
            }
        }
    }

    private mutating func syncGPU() {
        for i in 0..<grains.count {
            let g = grains[i]
            let u = 0.5 + g.x * 0.455
            let v = 0.5 + g.y * 0.455
            gpuGrains[i] = OneTapeGPUGrain(uv: SIMD2(u, v), sizePx: g.sizePx, shade: g.shade)
        }
    }
}
