import CoreGraphics
import Foundation
import simd

/// Packed 16-byte instanced iron needle filing sent to `ironFilingVertex`.
struct OneTapeGPUFiling {
    var uv: SIMD2<Float>
    var angle: Float
    var lengthAndShade: Float // integer part = length in logical pt (~4..8), fractional = shade [0..0.99]
}

/// Real 3,600-particle wind-blown desert sand dunes simulation (`dunes`).
/// Grains ride a curving wind vector whose direction slowly shifts with bass,
/// accumulating along drifting aeolian dune crests and lifting into streamers on kicks.
struct OneTapeDunesSimulation {
    static let grainCount = 3_600

    private struct Grain {
        var x: Float      // [0, 1] UV
        var y: Float
        var vx: Float
        var vy: Float
        var sizePx: Float
        var shade: Float
        var crestOffset: Float
    }

    private var grains: [Grain] = []
    private var rng = OneTapeFastRNG(seed: 0xD04E_5A4D)
    private var windPhase: Float = 0.35
    private var windAngle: Float = -0.32
    private(set) var gpuGrains: [OneTapeGPUGrain] = []

    init() {
        grains.reserveCapacity(Self.grainCount)
        gpuGrains = Array(repeating: OneTapeGPUGrain(uv: .zero, sizePx: 2.3, shade: 0.9), count: Self.grainCount)
        for _ in 0..<Self.grainCount {
            // Skewed lee-slope distribution: tight dark ridge crest + softer windward/leeward tail.
            let raw = (rng.nextFloat() * rng.nextFloat()) * 0.58 - 0.14
            grains.append(Grain(
                x: rng.nextFloat(),
                y: rng.nextFloat(),
                vx: 0,
                vy: 0,
                sizePx: 1.9 + rng.nextFloat() * 1.65,
                shade: 0.62 + rng.nextFloat() * 0.36,
                crestOffset: raw
            ))
        }
        settleInitialDunes()
        syncGPU()
    }

    mutating func step(dt rawDT: Double, envelope: OneTapeScreenAudioEnvelope, isPreview: Bool) {
        let dt = Float(min(0.033, max(0.001, rawDT)))
        let t = envelope.time
        // Bass quietly bends the wind direction across the panel.
        let targetAngle: Float = -0.34 + sin(t * 0.38) * 0.24 + (envelope.bass - 0.25) * 0.48
        windAngle += (targetAngle - windAngle) * min(1, dt * 1.8)

        let speed: Float = 0.28 + envelope.rms * 0.62 + envelope.bass * 0.35 + (isPreview ? 0.10 : 0)
        windPhase += speed * dt

        let cosA = cos(windAngle)
        let sinA = sin(windAngle)
        let dirX = cosA
        let dirY = sinA
        let perpX = -sinA
        let perpY = cosA

        let gust = envelope.kickImpulse
        let breeze = envelope.high * 0.14 + envelope.kick * 0.22 + (isPreview ? 0.03 : 0)
        let damp = exp(-dt * 4.8)

        for i in 0..<grains.count {
            var g = grains[i]
            let cx = g.x - 0.5
            let cy = g.y - 0.5
            // Project onto wind axis & cross-wind axis to form curving S-shaped barchan dune ridges.
            let along = cx * dirX + cy * dirY
            let across = cx * perpX + cy * perpY
            let curve = sin(across * 5.2 + windPhase * 0.45) * 0.085
                      + cos(across * 2.7 - windPhase * 0.28) * 0.045
            let freq: Float = 3.4 * Float.pi * 2.0
            let waveArg = (along + curve) * freq - windPhase * 1.9

            // Trapping force gathers sand onto moving dune crests while wind saltates grains downwind.
            let trap = -sin(waveArg - g.crestOffset * 2.2) * (0.42 + envelope.mid * 0.28)
            let drift = (0.048 + envelope.bass * 0.11 + envelope.rms * 0.06) * (0.55 + 0.45 * g.shade)

            g.vx += (dirX * (trap + drift) + perpX * cos(across * 4.0 + t) * 0.03) * dt
            g.vy += (dirY * (trap + drift) + perpY * sin(along * 4.0 + t) * 0.03) * dt

            if gust > 0.12 {
                let lift = gust * (0.35 + 0.65 * rng.nextFloat())
                g.vx += (dirX * 0.58 + rng.nextSigned() * 0.28) * lift
                g.vy += (dirY * 0.58 + rng.nextSigned() * 0.28) * lift
            }
            if breeze > 0.008 {
                g.vx += (dirX * 0.35 + rng.nextSigned() * 0.65) * breeze * dt * 2.2
                g.vy += (dirY * 0.35 + rng.nextSigned() * 0.65) * breeze * dt * 2.2
            }

            g.vx *= damp
            g.vy *= damp
            g.x += g.vx * dt
            g.y += g.vy * dt

            // Seamless wrap-around so dune grains continuously migrate across the entire LCD plate.
            if g.x < 0 { g.x += 1 } else if g.x >= 1 { g.x -= 1 }
            if g.y < 0 { g.y += 1 } else if g.y >= 1 { g.y -= 1 }
            grains[i] = g
        }
        syncGPU()
    }

    private mutating func settleInitialDunes() {
        let cosA = cos(windAngle)
        let sinA = sin(windAngle)
        let perpX = -sinA
        let perpY = cosA
        let freq: Float = 3.4 * Float.pi * 2.0
        for _ in 0..<20 {
            for i in 0..<grains.count {
                var g = grains[i]
                let cx = g.x - 0.5
                let cy = g.y - 0.5
                let along = cx * cosA + cy * sinA
                let across = cx * perpX + cy * perpY
                let curve = sin(across * 5.2 + windPhase * 0.45) * 0.085
                          + cos(across * 2.7 - windPhase * 0.28) * 0.045
                let waveArg = (along + curve) * freq - windPhase * 1.9
                let push = -sin(waveArg - g.crestOffset * 2.2) * 0.011
                g.x += cosA * push + rng.nextSigned() * 0.0025
                g.y += sinA * push + rng.nextSigned() * 0.0025
                if g.x < 0 { g.x += 1 } else if g.x >= 1 { g.x -= 1 }
                if g.y < 0 { g.y += 1 } else if g.y >= 1 { g.y -= 1 }
                grains[i] = g
            }
        }
    }

    private mutating func syncGPU() {
        for i in 0..<grains.count {
            let g = grains[i]
            let u = 0.025 + g.x * 0.95
            let v = 0.03 + g.y * 0.94
            gpuGrains[i] = OneTapeGPUGrain(uv: SIMD2(u, v), sizePx: g.sizePx, shade: g.shade)
        }
    }
}

/// Real 2D shallow-water heightfield wave solver (`water`).
/// Each beat drops a circular impulse onto the surface, bass pushes slow swells,
/// and highs scatter delicate wind shimmer across an 80×50 floating-point grid.
struct OneTapeWaterSimulation {
    static let gridW = 80
    static let gridH = 50
    static let cellCount = gridW * gridH

    private var curr = [Float](repeating: 0, count: cellCount)
    private var prev = [Float](repeating: 0, count: cellCount)
    private var next = [Float](repeating: 0, count: cellCount)
    private var rng = OneTapeFastRNG(seed: 0x57A7_E210)
    private var previewDropTimer: Float = 0.7
    private var accumulator: Double = 0

    var heightfield: [Float] { curr }

    init() {
        seedInitialRipples()
    }

    mutating func drop(u: Float, v: Float, strength: Float, radius: Float = 2.6) {
        let cx = u * Float(Self.gridW - 1)
        let cy = v * Float(Self.gridH - 1)
        let rInt = Int(ceil(radius * 2.2))
        let x0 = max(2, Int(floor(cx)) - rInt)
        let x1 = min(Self.gridW - 3, Int(ceil(cx)) + rInt)
        let y0 = max(2, Int(floor(cy)) - rInt)
        let y1 = min(Self.gridH - 3, Int(ceil(cy)) + rInt)
        let inv2R2 = 1.0 / (2.0 * radius * radius)
        for y in y0...y1 {
            let dy = Float(y) - cy
            let row = y * Self.gridW
            for x in x0...x1 {
                let dx = Float(x) - cx
                let w = exp(-(dx * dx + dy * dy) * inv2R2)
                curr[row + x] = max(-1.5, min(1.5, curr[row + x] + strength * w))
            }
        }
    }

    mutating func step(dt rawDT: Double, envelope: OneTapeScreenAudioEnvelope, isPreview: Bool) {
        let dt = min(0.05, max(0.001, rawDT))

        // Every musical beat drops a fresh crisp ripple ring onto the water surface.
        if envelope.kickImpulse > 0.14 {
            let u = 0.18 + rng.nextFloat() * 0.64
            let v = 0.20 + rng.nextFloat() * 0.60
            drop(u: u, v: v, strength: -(0.45 + envelope.kickImpulse * 0.55), radius: 2.3 + envelope.bass * 1.1)
        } else if isPreview {
            previewDropTimer -= Float(dt)
            if previewDropTimer <= 0 {
                previewDropTimer = 1.15 + rng.nextFloat() * 0.65
                let u = 0.22 + rng.nextFloat() * 0.56
                let v = 0.24 + rng.nextFloat() * 0.52
                drop(u: u, v: v, strength: -0.58, radius: 2.4)
            }
        }

        // Fixed 60Hz sub-step keeps the 2D wave PDE unconditionally stable across frame rates.
        accumulator += dt
        var steps = 0
        while accumulator >= (1.0 / 60.0) && steps < 2 {
            accumulator -= (1.0 / 60.0)
            advanceWaveTick(envelope: envelope)
            steps += 1
        }
    }

    private mutating func advanceWaveTick(envelope: OneTapeScreenAudioEnvelope) {
        let w = Self.gridW
        let h = Self.gridH
        let c2: Float = 0.21
        let damp: Float = 0.982
        let t = envelope.time
        let swellAmp = envelope.bass * 0.018
        let breezeAmp = envelope.high * 0.014

        for y in 1..<(h - 1) {
            let row = y * w
            let up = row - w
            let dn = row + w
            // Gentle edge absorption prevents harsh rectangular tank bounce.
            let edgeY: Float = (y < 4 || y > h - 5) ? 0.94 : 1.0
            for x in 1..<(w - 1) {
                let idx = row + x
                let lap = curr[idx - 1] + curr[idx + 1] + curr[up + x] + curr[dn + x] - 4.0 * curr[idx]
                var val = (2.0 * curr[idx] - prev[idx] + c2 * lap) * damp
                if x < 4 || x > w - 5 { val *= 0.94 }
                val *= edgeY

                if swellAmp > 0.001 && (x == 3 || x == w - 4) {
                    val += sin(t * 2.8 + Float(y) * 0.22) * swellAmp
                }
                if breezeAmp > 0.002 && rng.nextFloat() < 0.015 {
                    val += rng.nextSigned() * breezeAmp
                }
                next[idx] = max(-1.5, min(1.5, val))
            }
        }
        // Swap buffers with zero allocation.
        swap(&prev, &curr)
        swap(&curr, &next)
    }

    private mutating func seedInitialRipples() {
        let calmEnv = OneTapeScreenAudioEnvelope()
        drop(u: 0.34, v: 0.44, strength: -0.95, radius: 2.5)
        for _ in 0..<11 { advanceWaveTick(envelope: calmEnv) }
        drop(u: 0.67, v: 0.58, strength: -0.82, radius: 2.3)
        for _ in 0..<12 { advanceWaveTick(envelope: calmEnv) }
    }
}

/// Real 1,400-needle magnetic dipole iron filings simulation (`iron`).
/// Two moving magnetic dipoles curve every iron needle smoothly along the exact
/// 2D magnetic field lines while beat taps vibrate the paper underneath.
struct OneTapeIronSimulation {
    static let filingCount = 1_400

    private struct Filing {
        var x: Float       // [0, 1] UV
        var y: Float
        var vx: Float
        var vy: Float
        var homeX: Float
        var homeY: Float
        var angle: Float
        var angVel: Float
        var lengthPt: Float
        var shade: Float
    }

    private var filings: [Filing] = []
    private var rng = OneTapeFastRNG(seed: 0x1204_FE22)
    private var poleA = SIMD2<Float>(0.33, 0.48)
    private var poleB = SIMD2<Float>(0.67, 0.52)
    private(set) var gpuFilings: [OneTapeGPUFiling] = []

    init() {
        filings.reserveCapacity(Self.filingCount)
        gpuFilings = Array(repeating: OneTapeGPUFiling(uv: .zero, angle: 0, lengthAndShade: 5.85), count: Self.filingCount)
        for _ in 0..<Self.filingCount {
            let hx = 0.045 + rng.nextFloat() * 0.91
            let hy = 0.055 + rng.nextFloat() * 0.89
            let len = 4.2 + rng.nextFloat() * 3.4
            let shade = 0.74 + rng.nextFloat() * 0.24
            filings.append(Filing(
                x: hx, y: hy, vx: 0, vy: 0,
                homeX: hx, homeY: hy,
                angle: 0, angVel: 0,
                lengthPt: len, shade: shade
            ))
        }
        settleInitialField()
        syncGPU()
    }

    mutating func step(dt rawDT: Double, size: CGSize, envelope: OneTapeScreenAudioEnvelope, isPreview: Bool) {
        let dt = Float(min(0.033, max(0.001, rawDT)))
        let aspect = max(0.4, Float(size.width / max(1, size.height)))
        let t = envelope.time
        let bass = envelope.bass
        let kick = envelope.kickImpulse

        // Two magnetic poles slowly orbit & breathe apart with bass energy.
        let sep: Float = 0.175 + bass * 0.085 + sin(t * 0.55) * 0.035
        let orbitAng: Float = 0.18 + sin(t * 0.42) * 0.46 + (isPreview ? sin(t * 0.7) * 0.15 : 0)
        let dx = cos(orbitAng) * sep
        let dy = sin(orbitAng) * sep * (aspect >= 1 ? 0.82 : 1.18)
        poleA = SIMD2(0.5 - dx, 0.5 - dy)
        poleB = SIMD2(0.5 + dx, 0.5 + dy)

        let dampPos = exp(-dt * 7.5)
        let dampAng = exp(-dt * 9.5)

        for i in 0..<filings.count {
            var f = filings[i]
            let field = Self.magneticField(at: SIMD2(f.x, f.y), poleA: poleA, poleB: poleB, aspect: aspect)
            let targetAngle = atan2(field.y, field.x)

            // Shortest-path angular torque modulo pi (iron needles are end-to-end symmetric).
            var diff = targetAngle - f.angle
            while diff > Float.pi * 0.5 { diff -= Float.pi }
            while diff < -Float.pi * 0.5 { diff += Float.pi }

            let fieldMag = min(3.5, simd_length(field))
            let torque = diff * (16.0 + fieldMag * 10.0)
            f.angVel += torque * dt

            // Subtle magnetic attraction pulls filings slightly closer to strong pole flux arcs,
            // balanced by a soft spring back toward their distributed paper home.
            let toA = poleA - SIMD2(f.x, f.y)
            let toB = poleB - SIMD2(f.x, f.y)
            let dA2 = simd_length_squared(toA) + 0.012
            let dB2 = simd_length_squared(toB) + 0.012
            let pull = (toA / dA2 + toB / dB2) * 0.0022
            f.vx += ((f.homeX - f.x) * 4.8 + pull.x) * dt
            f.vy += ((f.homeY - f.y) * 4.8 + pull.y) * dt

            // Beat tap vibrates the paper underneath, rattling needles off-axis before they snap back.
            if kick > 0.12 {
                f.angVel += rng.nextSigned() * kick * 11.5
                f.vx += rng.nextSigned() * kick * 0.18
                f.vy += rng.nextSigned() * kick * 0.18
            } else if envelope.bass > 0.06 {
                f.angVel += rng.nextSigned() * envelope.bass * 3.2 * dt
            }

            f.angVel *= dampAng
            f.angle += f.angVel * dt
            f.vx *= dampPos
            f.vy *= dampPos
            f.x = max(0.03, min(0.97, f.x + f.vx * dt))
            f.y = max(0.035, min(0.965, f.y + f.vy * dt))
            filings[i] = f
        }
        syncGPU()
    }

    private mutating func settleInitialField() {
        let aspect: Float = 264.39 / 165.63
        for i in 0..<filings.count {
            var f = filings[i]
            // Subtle flux concentration toward poles so magnetic arches read unmistakably on frame 0.
            let toA = poleA - SIMD2(f.x, f.y)
            let toB = poleB - SIMD2(f.x, f.y)
            let dA = simd_length(toA)
            let dB = simd_length(toB)
            if dA < 0.24 && dA > 0.035 {
                let shift = toA * (0.14 * (1.0 - dA / 0.24))
                f.x += shift.x; f.y += shift.y
            } else if dB < 0.24 && dB > 0.035 {
                let shift = toB * (0.14 * (1.0 - dB / 0.24))
                f.x += shift.x; f.y += shift.y
            }
            let field = Self.magneticField(at: SIMD2(f.x, f.y), poleA: poleA, poleB: poleB, aspect: aspect)
            f.angle = atan2(field.y, field.x) + rng.nextSigned() * 0.06
            filings[i] = f
        }
    }

    private static func magneticField(
        at p: SIMD2<Float>,
        poleA: SIMD2<Float>,
        poleB: SIMD2<Float>,
        aspect: Float
    ) -> SIMD2<Float> {
        let rA = SIMD2((p.x - poleA.x) * aspect, p.y - poleA.y)
        let rB = SIMD2((p.x - poleB.x) * aspect, p.y - poleB.y)
        let invA = pow(simd_length_squared(rA) + 0.0045, -1.5)
        let invB = pow(simd_length_squared(rB) + 0.0045, -1.5)
        // North pole (+1) pushes outward; South pole (-1) pulls inward -> classic arching dipole loops.
        return rA * invA - rB * invB
    }

    private mutating func syncGPU() {
        for i in 0..<filings.count {
            let f = filings[i]
            let packedLen = floor(f.lengthPt * 10.0) / 10.0
            let shadeFrac = max(0.01, min(0.99, f.shade))
            // Encode length in integer slot (x100) + shade in fractional [0.01..0.99] cleanly:
            // Actually pack integer part = round(lengthPt * 10), fractional = shade * 0.99!
            let encoded = floor(packedLen * 10.0) + shadeFrac * 0.99
            gpuFilings[i] = OneTapeGPUFiling(uv: SIMD2(f.x, f.y), angle: f.angle, lengthAndShade: encoded)
        }
    }
}
