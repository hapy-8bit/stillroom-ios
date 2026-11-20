import SwiftUI

/// The clock interpolates decoration only; media snapshots remain the source of displayed time.
struct MechanicalHousing: View {
    let elapsed: Double
    let remaining: Double
    let playing: Bool
    let trackID: String
    let reducedMotion: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.roomMotionVisible) private var motionVisible
    @State private var leftMotion = MechanicalWheelMotion(rate: -6)
    @State private var rightMotion = MechanicalWheelMotion(rate: 6)
    @State private var settling = false

    private var sample: WheelSample {
        WheelSample(elapsed: elapsed, remaining: remaining,
                    running: playing && motionVisible && scenePhase == .active, trackID: trackID)
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            TimelineView(.animation(minimumInterval: 1.0 / 60,
                                    paused: !motionVisible || reducedMotion || scenePhase != .active || (!playing && !settling))) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                ZStack(alignment: .topLeading) {
                    MechanicalCardStyle.recess.allowsHitTesting(false)
                    MechanicalPaperRotor(size: size, radius: size.width * 0.62, centerX: size.width * 0.31,
                                         depth: MechanicalCardStyle.leftDepth(size.width), slotWidth: size.width * 0.16,
                                         digits: 2, angle: reducedMotion ? -elapsed * 6 : leftMotion.angle(at: time),
                                         reducedMotion: reducedMotion, label: "已播放纸轮", identifier: "home.wheel.elapsed")
                    MechanicalPaperRotor(size: size, radius: size.width * 0.81, centerX: size.width * 0.755,
                                         depth: MechanicalCardStyle.rightDepth(size.width), slotWidth: size.width * 0.235,
                                         digits: 3, angle: reducedMotion ? -remaining * 6 : rightMotion.angle(at: time),
                                         reducedMotion: reducedMotion, label: "剩余时间纸轮", identifier: "home.wheel.remaining")
                    Circle().fill(MechanicalCardStyle.wheelEdge)
                        .frame(width: size.width * 0.15, height: size.width * 0.15)
                        .position(x: size.width * 0.5, y: size.height + size.width * 0.061).allowsHitTesting(false)
                    MechanicalFaceplate().fill(
                        LinearGradient(colors: [MechanicalCardStyle.faceLight, MechanicalCardStyle.faceDark],
                                       startPoint: .topLeading, endPoint: .bottomTrailing), style: FillStyle(eoFill: true))
                        .allowsHitTesting(false)
                    MechanicalFaceplate().stroke(
                        LinearGradient(colors: [.white.opacity(0.24), .white.opacity(0.035), .black.opacity(0.6)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8).allowsHitTesting(false)
                    LinearGradient(stops: [.init(color: .black.opacity(0.32), location: 0),
                                           .init(color: .clear, location: 0.25),
                                           .init(color: .clear, location: 0.7),
                                           .init(color: .black.opacity(0.25), location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: MechanicalCardStyle.rightDepth(size.width))
                        .mask(MechanicalSlots()).allowsHitTesting(false)
                }.clipShape(RoundedRectangle(cornerRadius: MechanicalCardStyle.cornerRadius))
            }
        }
        .onChange(of: sample, initial: true) { previous, next in
            let time = Date.now.timeIntervalSinceReferenceDate
            leftMotion.observe(seconds: next.elapsed, running: next.running, remaining: next.remaining,
                               at: time, reset: previous.trackID != next.trackID)
            rightMotion.observe(seconds: next.remaining, running: next.running, remaining: next.remaining,
                                at: time, reset: previous.trackID != next.trackID)
            settling = !reducedMotion
        }
        .task(id: sample) {
            guard !sample.running else { return }
            // This cancellable delay only retires the visual clock after a paused seek settles.
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            settling = false
        }
        .onDisappear { settling = false }
    }
}

private struct WheelSample: Equatable {
    let elapsed: Double
    let remaining: Double
    let running: Bool
    let trackID: String
}

private struct MechanicalFaceplate: Shape {
    func path(in rect: CGRect) -> Path {
        var path = RoundedRectangle(cornerRadius: MechanicalCardStyle.cornerRadius).path(in: rect)
        path.addPath(MechanicalSlots().path(in: rect))
        path.addRect(CGRect(x: rect.width * 0.425, y: rect.height - 5, width: rect.width * 0.15, height: 7))
        return path
    }
}

private struct MechanicalSlots: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path(CGRect(x: rect.width * 0.23, y: -1, width: rect.width * 0.16,
                               height: MechanicalCardStyle.leftDepth(rect.width) + 1))
        path.move(to: CGPoint(x: rect.width * 0.64, y: -1))
        path.addLine(to: CGPoint(x: rect.width * 0.875, y: -1))
        path.addLine(to: CGPoint(x: rect.width * 0.8, y: MechanicalCardStyle.rightDepth(rect.width)))
        path.addLine(to: CGPoint(x: rect.width * 0.71, y: MechanicalCardStyle.rightDepth(rect.width)))
        path.closeSubpath()
        return path
    }
}
