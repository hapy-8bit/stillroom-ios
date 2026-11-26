import CoreGraphics
import Foundation
import simd
import UIKit

/// Real 3,200-particle sand typography simulation for the current track title & artist.
/// Extracts dense uniform targets straight from CoreText glyphs so letters are razor-sharp
/// when settled, explode into individual drifting sand grains on beats, and physically morph
/// when switching tracks.
struct OneTapeNameSandSimulation {
    static let grainCount = 3_200

    private struct Grain {
        var x: Float      // [0, 1] UV
        var y: Float
        var vx: Float
        var vy: Float
        var homeX: Float
        var homeY: Float
        var sizePx: Float
        var shade: Float
        var isAmbient: Bool
    }

    private var grains: [Grain] = []
    private var rng = OneTapeFastRNG(seed: 0xA4E5_A17D)
    private var cachedKey: String = ""
    private var hasInitializedPositions = false
    private(set) var gpuGrains: [OneTapeGPUGrain] = []

    init() {
        grains.reserveCapacity(Self.grainCount)
        gpuGrains = Array(repeating: OneTapeGPUGrain(uv: .zero, sizePx: 2.3, shade: 0.9), count: Self.grainCount)
        for i in 0..<Self.grainCount {
            let ambient = i >= Self.grainCount - 95
            let rx = 0.05 + rng.nextFloat() * 0.90
            let ry = 0.06 + rng.nextFloat() * 0.88
            grains.append(Grain(
                x: rx, y: ry, vx: 0, vy: 0,
                homeX: rx, homeY: ry,
                sizePx: ambient ? (1.7 + rng.nextFloat() * 1.1) : (2.1 + rng.nextFloat() * 1.35),
                shade: ambient ? (0.45 + rng.nextFloat() * 0.28) : (0.80 + rng.nextFloat() * 0.20),
                isAmbient: ambient
            ))
        }
    }

    /// Rebuilds sand letter target coordinates only when track metadata or settled aspect changes.
    /// Avoids churning CoreText during mid-turn orientation animations.
    mutating func configure(title: String, artist: String, logicalSize: CGSize) {
        let isTall = logicalSize.height > logicalSize.width * 1.05
        let isWide = logicalSize.width > logicalSize.height * 1.05
        guard isTall || isWide else { return }

        let targetW = isTall ? 166 : 264
        let targetH = isTall ? 264 : 166
        let key = "\(title)\u{0}\(artist)\u{0}\(targetW)x\(targetH)"
        guard key != cachedKey else { return }
        cachedKey = key

        let targets = Self.sampleLetterTargets(
            title: title,
            artist: artist,
            width: targetW * 2,
            height: targetH * 2,
            needed: Self.grainCount - 95,
            rng: &rng
        )

        let snapImmediate = !hasInitializedPositions
        hasInitializedPositions = true

        for i in 0..<grains.count {
            if grains[i].isAmbient || targets.isEmpty {
                let hx = 0.04 + rng.nextFloat() * 0.92
                let hy = 0.05 + rng.nextFloat() * 0.90
                grains[i].homeX = hx
                grains[i].homeY = hy
                if snapImmediate {
                    grains[i].x = hx
                    grains[i].y = hy
                    grains[i].vx = 0
                    grains[i].vy = 0
                }
            } else {
                let pt = targets[i % targets.count]
                grains[i].homeX = pt.x
                grains[i].homeY = pt.y
                if snapImmediate {
                    grains[i].x = pt.x
                    grains[i].y = pt.y
                    grains[i].vx = 0
                    grains[i].vy = 0
                } else {
                    grains[i].vx += rng.nextSigned() * 0.45
                    grains[i].vy += rng.nextSigned() * 0.45
                }
            }
        }
        syncGPU()
    }

    mutating func step(dt rawDT: Double, envelope: OneTapeScreenAudioEnvelope) {
        let dt = Float(min(0.033, max(0.001, rawDT)))
        let burst = envelope.kickImpulse
        let tremble = envelope.bass * 0.055 + envelope.kick * 0.085
        let springK: Float = 26.0
        let damp = exp(-dt * 7.8)

        for i in 0..<grains.count {
            var g = grains[i]
            let dx = g.homeX - g.x
            let dy = g.homeY - g.y
            g.vx += dx * springK * dt
            g.vy += dy * springK * dt

            if burst > 0.14 {
                let fromCenterX = g.x - 0.5
                let fromCenterY = g.y - 0.5
                let ang = rng.nextFloat() * Float.pi * 2.0
                let spread = burst * (g.isAmbient ? 0.55 : 0.44)
                g.vx += (cos(ang) * 0.72 + fromCenterX * 0.85) * spread
                g.vy += (sin(ang) * 0.72 + fromCenterY * 0.85) * spread
            }
            if tremble > 0.008 {
                g.vx += rng.nextSigned() * tremble * 3.8 * dt
                g.vy += rng.nextSigned() * tremble * 3.8 * dt
            }

            g.vx *= damp
            g.vy *= damp
            g.x = max(0.015, min(0.985, g.x + g.vx * dt))
            g.y = max(0.015, min(0.985, g.y + g.vy * dt))
            grains[i] = g
        }
        syncGPU()
    }

    private mutating func syncGPU() {
        for i in 0..<grains.count {
            let g = grains[i]
            gpuGrains[i] = OneTapeGPUGrain(uv: SIMD2(g.x, g.y), sizePx: g.sizePx, shade: g.shade)
        }
    }

    private static func sampleLetterTargets(
        title: String,
        artist: String,
        width w: Int,
        height h: Int,
        needed: Int,
        rng: inout OneTapeFastRNG
    ) -> [SIMD2<Float>] {
        var mask = [UInt8](repeating: 0, count: w * h)
        let cs = CGColorSpaceCreateDeviceGray()
        let ok: Bool = mask.withUnsafeMutableBytes { raw in
            guard let base = raw.baseAddress,
                  let ctx = CGContext(
                    data: base, width: w, height: h,
                    bitsPerComponent: 8, bytesPerRow: w,
                    space: cs, bitmapInfo: CGImageAlphaInfo.none.rawValue
                  ) else { return false }
            ctx.setFillColor(gray: 0, alpha: 1)
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

            UIGraphicsPushContext(ctx)
            ctx.translateBy(x: 0, y: CGFloat(h))
            ctx.scaleBy(x: 2.0, y: -2.0)

            let size = CGSize(width: CGFloat(w) / 2.0, height: CGFloat(h) / 2.0)
            let isTall = size.height > size.width
            let padX: CGFloat = isTall ? 11.0 : 15.0
            let boxW = size.width - padX * 2.0

            let titleStyle = NSMutableParagraphStyle()
            titleStyle.alignment = .center
            titleStyle.lineBreakMode = .byWordWrapping
            titleStyle.lineSpacing = 1.0

            // Smart auto-fit: starts bold & generous and steps down smoothly so short/medium
            // titles never clip mid-word while long titles wrap neatly up to 2-3 lines.
            let titleNS = title as NSString
            let maxLines: CGFloat = isTall ? 3.1 : 2.15
            let maxAllowedTitleH = size.height * (isTall ? 0.52 : 0.56)
            var chosenTitlePt: CGFloat = isTall ? 26.0 : 34.0
            let minTitlePt: CGFloat = isTall ? 15.5 : 18.0
            var titleFont = UIFont.systemFont(ofSize: chosenTitlePt, weight: .black)
            var titleAttrs: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.white,
                .paragraphStyle: titleStyle
            ]
            var measured = CGSize.zero
            while chosenTitlePt >= minTitlePt {
                titleFont = UIFont.systemFont(ofSize: chosenTitlePt, weight: .black)
                titleAttrs[.font] = titleFont
                let rawSize = titleNS.boundingRect(
                    with: CGSize(width: boxW, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: titleAttrs,
                    context: nil
                ).size
                let lineLimitH = titleFont.lineHeight * maxLines
                measured = rawSize
                if rawSize.height <= min(lineLimitH, maxAllowedTitleH) && rawSize.width <= boxW + 0.5 {
                    break
                }
                chosenTitlePt -= 2.0
            }

            let artistStyle = NSMutableParagraphStyle()
            artistStyle.alignment = .center
            artistStyle.lineBreakMode = .byTruncatingTail
            var artistPt: CGFloat = isTall ? 13.5 : 16.0
            let artistNS = artist as NSString
            var artistFont = UIFont.systemFont(ofSize: artistPt, weight: .bold)
            var artistAttrs: [NSAttributedString.Key: Any] = [
                .font: artistFont,
                .foregroundColor: UIColor(white: 0.92, alpha: 1),
                .paragraphStyle: artistStyle
            ]
            if !artist.isEmpty {
                while artistPt > 11.0 {
                    artistFont = UIFont.systemFont(ofSize: artistPt, weight: .bold)
                    artistAttrs[.font] = artistFont
                    let wArtist = artistNS.size(withAttributes: artistAttrs).width
                    if wArtist <= boxW { break }
                    artistPt -= 1.0
                }
            }

            let titleH = min(titleFont.lineHeight * maxLines, ceil(measured.height))
            let artistH = artist.isEmpty ? 0 : ceil(artistFont.lineHeight)
            let gap: CGFloat = artist.isEmpty ? 0 : (isTall ? 11.0 : 9.0)
            let totalH = titleH + gap + artistH
            let startY = max(10, (size.height - totalH) * 0.5)

            titleNS.draw(
                with: CGRect(x: padX, y: startY, width: boxW, height: titleH),
                options: [.usesLineFragmentOrigin, .usesFontLeading, .truncatesLastVisibleLine],
                attributes: titleAttrs,
                context: nil
            )
            if !artist.isEmpty {
                artistNS.draw(
                    with: CGRect(x: padX, y: startY + titleH + gap, width: boxW, height: artistH),
                    options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                    attributes: artistAttrs,
                    context: nil
                )
            }
            UIGraphicsPopContext()
            return true
        }
        guard ok else { return [] }

        var lit: [SIMD2<Float>] = []
        lit.reserveCapacity(12_000)
        let invW = 1.0 / Float(w)
        let invH = 1.0 / Float(h)
        // Stride by 2 in 2× pixels (~1 logical pt spacing) for clean dense coverage.
        for y in stride(from: 0, to: h, by: 2) {
            let row = y * w
            for x in stride(from: 0, to: w, by: 2) {
                if mask[row + x] > 110 {
                    let u = (Float(x) + 0.5 + rng.nextSigned() * 0.65) * invW
                    let v = (Float(y) + 0.5 + rng.nextSigned() * 0.65) * invH
                    lit.append(SIMD2(u, v))
                }
            }
        }
        guard !lit.isEmpty else { return [] }

        // Deterministic partial Fisher-Yates selection ensures uniform non-striped grain fill.
        if lit.count > needed {
            for i in 0..<needed {
                let j = i + Int(rng.nextUInt32() % UInt32(lit.count - i))
                lit.swapAt(i, j)
            }
            return Array(lit.prefix(needed))
        }
        // If text is short, replicate with subtle micro-jitter so strokes stay richly filled with sand.
        var out = lit
        out.reserveCapacity(needed)
        while out.count < needed {
            let base = lit[Int(rng.nextUInt32() % UInt32(lit.count))]
            out.append(SIMD2(
                max(0.02, min(0.98, base.x + rng.nextSigned() * 0.0032)),
                max(0.02, min(0.98, base.y + rng.nextSigned() * 0.0032))
            ))
        }
        return out
    }
}
