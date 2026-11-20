import SwiftUI
import UIKit

/// Physical circular hardware key mounted in the player's top-left bezel to
/// cycle playback modes (list loop -> single loop -> shuffle). Its engraved
/// glyph tracks only portrait (0) and left-landscape (+90°) orientation.
struct OneTapePlaybackModeKey: View {
    let mode: OneTapePlaybackMode
    let appearance: OneTapeAppearance
    var artworkColor: OneTapeTransportMaterial.RGB? = nil
    let hitDiameter: CGFloat
    var quarterTurns: Int = 0
    let action: () -> Void

    static let visualDiameter: CGFloat = 46

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @GestureState private var pressed = false

    private var material: OneTapeTransportMaterial {
        OneTapeTransportMaterial(appearance: appearance, artworkColor: artworkColor)
    }

    /// Guard against any stale negative/rightward turn: only 0° and +90° (leftward).
    private var clampedLeftTurn: Int { quarterTurns == 1 ? 1 : 0 }

    private var glyphColor: Color {
        if material.usesOriginalArtwork {
            return Color(red: 0.62, green: 0.63, blue: 0.62)
        }
        return Color(red: material.symbol.red, green: material.symbol.green, blue: material.symbol.blue)
    }

    private var accentColor: Color {
        let luminance = 0.2126 * material.face.red + 0.7152 * material.face.green + 0.0722 * material.face.blue
        return luminance > 0.45
            ? Color(red: 0.76, green: 0.28, blue: 0.12)
            : Color(red: 0.94, green: 0.48, blue: 0.18)
    }

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            ZStack {
                capSurface
                OneTapePlaybackModeGlyph(mode: mode, color: glyphColor, accent: accentColor)
                    .rotationEffect(.degrees(Double(clampedLeftTurn) * 90))
                    .animation(reduceMotion || scenePhase != .active ? nil
                        : .timingCurve(0.25, 0.1, 0.25, 1, duration: 0.32), value: clampedLeftTurn)
                depressionOverlay
            }
            .frame(width: Self.visualDiameter, height: Self.visualDiameter)
            .scaleEffect(pressed && !reduceMotion ? 0.96 : 1)
            .frame(width: hitDiameter, height: hitDiameter)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($pressed) { _, value, _ in value = true }
        )
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: pressed)
        .accessibilityIdentifier("tape.mode")
        .accessibilityLabel("播放模式")
        .accessibilityValue(mode.title)
        .accessibilityHint("轻点切换\(mode.next.title)")
    }

    @ViewBuilder
    private var capSurface: some View {
        if let surface = appearance.bodyMaterial {
            OneTapeMaterialKeySurface(material: surface, palette: surface.palette(color: appearance.bodyColor))
                .scaleEffect(Self.visualDiameter / OneTapeTransportGeometry.visualDiameter)
                .frame(width: Self.visualDiameter, height: Self.visualDiameter)
                .clipShape(Circle())
        } else {
            machinedKey
        }
    }

    private var machinedKey: some View {
        let face = Color(red: material.face.red, green: material.face.green, blue: material.face.blue)
        return ZStack {
            Circle().fill(Color.black.opacity(0.84))
            Circle()
                .fill(LinearGradient(colors: [
                    Color.white.opacity(material.usesOriginalArtwork ? 0.30 : 0.38),
                    face, Color.black.opacity(0.45),
                    Color.white.opacity(0.18)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                .padding(0.8)
            Circle()
                .fill(RadialGradient(colors: [
                    face.opacity(0.95),
                    face
                ], center: UnitPoint(x: 0.35, y: 0.25), startRadius: 0, endRadius: Self.visualDiameter * 0.7))
                .overlay {
                    Circle().strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.28), .clear, .black.opacity(0.25)],
                            startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8)
                }
                .padding(3.2)
        }
        .clipShape(Circle())
    }

    private var depressionOverlay: some View {
        Circle()
            .fill(.black.opacity(pressed ? 0.16 : 0))
            .overlay {
                Circle().strokeBorder(.black.opacity(pressed ? 0.45 : 0), lineWidth: 2.5)
            }
            .padding(3.2)
            .clipShape(Circle())
            .allowsHitTesting(false)
    }
}

/// Custom vector icons crafted cleanly at 18×18 logical points for crisp legibility
/// across every shell finish and orientation turn.
struct OneTapePlaybackModeGlyph: View {
    let mode: OneTapePlaybackMode
    let color: Color
    let accent: Color

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let stroke = StrokeStyle(lineWidth: 1.65, lineCap: .round, lineJoin: .round)

            switch mode {
            case .listLoop:
                drawLoopTrack(in: &context, width: w, height: h, color: color, stroke: stroke)
            case .singleLoop:
                drawLoopTrack(in: &context, width: w, height: h, color: color, stroke: stroke)
                drawCenterOne(in: &context, width: w, height: h, color: accent)
            case .shuffle:
                drawShuffleWeave(in: &context, width: w, height: h, color: color, accent: accent, stroke: stroke)
            }
        }
        .frame(width: 18, height: 18)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawLoopTrack(in context: inout GraphicsContext, width w: CGFloat, height h: CGFloat,
                               color: Color, stroke: StrokeStyle) {
        // Upper forward arc ending with chevron arrow at top-right
        var top = Path()
        top.move(to: CGPoint(x: 2.2, y: h * 0.46))
        top.addLine(to: CGPoint(x: 2.2, y: h * 0.34))
        top.addQuadCurve(to: CGPoint(x: 5.5, y: h * 0.22), control: CGPoint(x: 2.2, y: h * 0.22))
        top.addLine(to: CGPoint(x: w - 3.6, y: h * 0.22))
        context.stroke(top, with: .color(color), style: stroke)

        var topHead = Path()
        topHead.move(to: CGPoint(x: w - 6.0, y: h * 0.22 - 2.3))
        topHead.addLine(to: CGPoint(x: w - 3.2, y: h * 0.22))
        topHead.addLine(to: CGPoint(x: w - 6.0, y: h * 0.22 + 2.3))
        context.stroke(topHead, with: .color(color), style: stroke)

        // Lower return arc ending with symmetric chevron arrow at bottom-left
        var bottom = Path()
        bottom.move(to: CGPoint(x: w - 2.2, y: h * 0.54))
        bottom.addLine(to: CGPoint(x: w - 2.2, y: h * 0.66))
        bottom.addQuadCurve(to: CGPoint(x: w - 5.5, y: h * 0.78), control: CGPoint(x: w - 2.2, y: h * 0.78))
        bottom.addLine(to: CGPoint(x: 3.6, y: h * 0.78))
        context.stroke(bottom, with: .color(color), style: stroke)

        var bottomHead = Path()
        bottomHead.move(to: CGPoint(x: 6.0, y: h * 0.78 - 2.3))
        bottomHead.addLine(to: CGPoint(x: 3.2, y: h * 0.78))
        bottomHead.addLine(to: CGPoint(x: 6.0, y: h * 0.78 + 2.3))
        context.stroke(bottomHead, with: .color(color), style: stroke)
    }

    private func drawCenterOne(in context: inout GraphicsContext, width w: CGFloat, height h: CGFloat, color: Color) {
        let cx = w * 0.5
        let cy = h * 0.50
        var glyph = Path()
        glyph.move(to: CGPoint(x: cx - 1.5, y: cy - 1.3))
        glyph.addLine(to: CGPoint(x: cx + 0.3, y: cy - 2.4))
        glyph.addLine(to: CGPoint(x: cx + 0.3, y: cy + 2.5))
        glyph.move(to: CGPoint(x: cx - 1.3, y: cy + 2.5))
        glyph.addLine(to: CGPoint(x: cx + 1.9, y: cy + 2.5))
        context.stroke(glyph, with: .color(color),
                       style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
    }

    private func drawShuffleWeave(in context: inout GraphicsContext, width w: CGFloat, height h: CGFloat,
                                  color: Color, accent: Color, stroke: StrokeStyle) {
        // Under-pass curve (bottom-left -> top-right), broken at center weave
        var underLeft = Path()
        underLeft.move(to: CGPoint(x: 2.2, y: h * 0.72))
        underLeft.addLine(to: CGPoint(x: w * 0.28, y: h * 0.72))
        underLeft.addLine(to: CGPoint(x: w * 0.40, y: h * 0.59))
        context.stroke(underLeft, with: .color(color), style: stroke)

        var underRight = Path()
        underRight.move(to: CGPoint(x: w * 0.60, y: h * 0.41))
        underRight.addLine(to: CGPoint(x: w * 0.72, y: h * 0.28))
        underRight.addLine(to: CGPoint(x: w - 3.6, y: h * 0.28))
        context.stroke(underRight, with: .color(color), style: stroke)

        // Over-pass unbroken ribbon (top-left -> bottom-right)
        var over = Path()
        over.move(to: CGPoint(x: 2.2, y: h * 0.28))
        over.addLine(to: CGPoint(x: w * 0.28, y: h * 0.28))
        over.addLine(to: CGPoint(x: w * 0.72, y: h * 0.72))
        over.addLine(to: CGPoint(x: w - 3.6, y: h * 0.72))
        context.stroke(over, with: .color(accent), style: stroke)

        for y in [h * 0.28, h * 0.72] {
            var head = Path()
            head.move(to: CGPoint(x: w - 5.9, y: y - 2.2))
            head.addLine(to: CGPoint(x: w - 3.1, y: y))
            head.addLine(to: CGPoint(x: w - 5.9, y: y + 2.2))
            context.stroke(head, with: .color(y < h * 0.5 ? color : accent), style: stroke)
        }
    }
}
