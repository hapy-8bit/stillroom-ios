import SwiftUI

/// Interactive listening rhythm card switching between a 24-hour analog VU meter
/// and daily trend bars / retro pixel heatmap, supporting finger scrubbing with haptics.
struct OneTapeInsightsRhythmCard: View {
    enum Mode: String, CaseIterable, Identifiable {
        case hourly, daily
        var id: String { rawValue }
        var title: String { self == .hourly ? "时段" : "趋势" }
    }

    let snapshot: ListeningInsightsSnapshot
    let revealTrigger: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mode: Mode = .hourly
    @State private var scrubbedHour: Int?
    @State private var scrubbedDayIndex: Int?
    @State private var hapticToken = 0
    @State private var growth: CGFloat = 0

    private let accent = Color(red: 0.87, green: 0.55, blue: 0.25)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("聆听节律")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                    Text(activeReadoutLine)
                        .font(.custom("GeistMono-Regular", size: 11))
                        .foregroundStyle(isScrubbing ? accent : .white.opacity(0.46))
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                modePicker
            }

            if mode == .hourly {
                hourlyMeter
            } else if snapshot.range == .week {
                weeklyBars
            } else {
                dailyPixelMatrix
            }

            Text(snapshot.rhythmSummary)
                .font(.system(size: 12.5))
                .foregroundStyle(.white.opacity(0.56))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(18)
        .background(.white.opacity(0.036), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.075), lineWidth: 0.6)
        }
        .sensoryFeedback(.selection, trigger: hapticToken)
        .accessibilityIdentifier("insights.rhythmCard")
        .onAppear { animateGrowth() }
        .onChange(of: snapshot.range) { _, _ in
            scrubbedHour = nil
            scrubbedDayIndex = nil
            animateGrowth()
        }
        .onChange(of: mode) { _, _ in
            scrubbedHour = nil
            scrubbedDayIndex = nil
            animateGrowth()
        }
        .onChange(of: revealTrigger) { _, _ in animateGrowth() }
    }

    private var isScrubbing: Bool {
        scrubbedHour != nil || scrubbedDayIndex != nil
    }

    private var activeReadoutLine: String {
        if mode == .hourly, let hour = scrubbedHour, snapshot.hourlyMinutes.indices.contains(hour) {
            let next = (hour + 1) % 24
            let mins = snapshot.hourlyMinutes[hour]
            return String(format: "%02d:00–%02d:00 · %@", hour, next, formatMinutes(mins))
        }
        if mode == .daily, let idx = scrubbedDayIndex, snapshot.dailySeries.indices.contains(idx) {
            let point = snapshot.dailySeries[idx]
            return "\(point.dateLabel) \(point.weekdayLabel) · \(formatMinutes(point.minutes))"
        }
        if mode == .hourly {
            return snapshot.peakHour != nil ? "峰值时段 · \(snapshot.peakWindowLabel)" : "滑动刻度可查看每小时时长"
        }
        let activeDays = snapshot.dailySeries.filter { $0.minutes > 0 }.count
        return activeDays > 0 ? "活跃 \(activeDays) 天 · 轻按格子可查单日" : "轻按或滑动可查看单日记录"
    }

    private var modePicker: some View {
        HStack(spacing: 2) {
            ForEach(Mode.allCases) { item in
                let selected = mode == item
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                        mode = item
                    }
                } label: {
                    Text(item.title)
                        .font(.system(size: 11.5, weight: selected ? .semibold : .medium))
                        .foregroundStyle(.white.opacity(selected ? 0.94 : 0.48))
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background {
                            if selected {
                                Capsule().fill(.white.opacity(0.14))
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("insights.rhythm.\(item.rawValue)")
            }
        }
        .padding(3)
        .background(.white.opacity(0.05), in: Capsule())
    }

    // MARK: - 24h Analog VU Meter

    private var hourlyMeter: some View {
        let maxVal = max(snapshot.hourlyMinutes.max() ?? 0, 1)
        let peakThreshold = (snapshot.hourlyMinutes.max() ?? 0) * 0.78

        return VStack(spacing: 7) {
            GeometryReader { geometry in
                let count = 24
                let gap: CGFloat = 3.5
                let barWidth = max(3, (geometry.size.width - CGFloat(count - 1) * gap) / CGFloat(count))

                HStack(alignment: .bottom, spacing: gap) {
                    ForEach(0..<count, id: \.self) { hour in
                        let value = snapshot.hourlyMinutes.indices.contains(hour) ? snapshot.hourlyMinutes[hour] : 0
                        let fraction = value > 0 ? max(0.09, value / maxVal) : 0
                        let isSelected = scrubbedHour == hour
                        let isPeak = value > 0 && value >= peakThreshold
                        let barColor: Color = isSelected
                            ? accent
                            : (isPeak ? accent.opacity(0.88) : .white.opacity(value > 0 ? 0.56 : 0.08))

                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(.white.opacity(isSelected ? 0.11 : 0.045))
                                .frame(width: barWidth, height: geometry.size.height)

                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(barColor)
                                .frame(
                                    width: barWidth,
                                    height: max(value > 0 ? 4 : 2, geometry.size.height * CGFloat(fraction) * growth)
                                )
                        }
                        .frame(width: barWidth, height: geometry.size.height, alignment: .bottom)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let ratio = min(max(0, value.location.x / max(1, geometry.size.width)), 0.999)
                            let hour = Int(ratio * 24)
                            if scrubbedHour != hour {
                                scrubbedHour = hour
                                hapticToken += 1
                            }
                        }
                        .onEnded { _ in
                            scrubbedHour = nil
                        }
                )
            }
            .frame(height: 92)

            HStack {
                Text("00")
                Spacer()
                Text("06")
                Spacer()
                Text("12")
                Spacer()
                Text("18")
                Spacer()
                Text("23")
            }
            .font(.custom("GeistMono-Regular", size: 10))
            .foregroundStyle(.white.opacity(0.36))
        }
    }

    // MARK: - 7-Day Mechanical Scale Bars

    private var weeklyBars: some View {
        let points = snapshot.dailySeries
        let maxVal = max(points.map(\.minutes).max() ?? 0, 1)

        return GeometryReader { geometry in
            let count = max(1, points.count)
            let gap: CGFloat = 10
            let colWidth = max(14, (geometry.size.width - CGFloat(count - 1) * gap) / CGFloat(count))
            let barAreaHeight = geometry.size.height - 20

            HStack(alignment: .bottom, spacing: gap) {
                ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                    let fraction = point.minutes > 0 ? max(0.08, point.minutes / maxVal) : 0
                    let isSelected = scrubbedDayIndex == index
                    let fill: Color = isSelected || point.isToday
                        ? accent.opacity(point.minutes > 0 ? 0.95 : 0.28)
                        : .white.opacity(point.minutes > 0 ? 0.60 : 0.08)

                    VStack(spacing: 6) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(.white.opacity(isSelected ? 0.11 : 0.045))
                                .frame(width: colWidth, height: barAreaHeight)

                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(fill)
                                .frame(
                                    width: colWidth,
                                    height: max(point.minutes > 0 ? 5 : 2, barAreaHeight * CGFloat(fraction) * growth)
                                )
                        }
                        .frame(height: barAreaHeight, alignment: .bottom)

                        Text(point.weekdayLabel)
                            .font(.system(size: 10, weight: point.isToday || isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? accent : .white.opacity(point.isToday ? 0.80 : 0.42))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(width: colWidth)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let ratio = min(max(0, value.location.x / max(1, geometry.size.width)), 0.999)
                        let idx = min(points.count - 1, max(0, Int(ratio * Double(points.count))))
                        if scrubbedDayIndex != idx {
                            scrubbedDayIndex = idx
                            hapticToken += 1
                        }
                    }
                    .onEnded { _ in
                        scrubbedDayIndex = nil
                    }
            )
        }
        .frame(height: 112)
    }

    // MARK: - 30-Day / All-Time Retro Pixel Heatmap

    private var dailyPixelMatrix: some View {
        let points = snapshot.dailySeries
        let maxVal = max(points.map(\.minutes).max() ?? 0, 1)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

        return VStack(spacing: 8) {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                    let level = intensityLevel(minutes: point.minutes, maxVal: maxVal)
                    let isSelected = scrubbedDayIndex == index

                    Button {
                        scrubbedDayIndex = isSelected ? nil : index
                        hapticToken += 1
                    } label: {
                        RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                            .fill(cellColor(level: level, isSelected: isSelected))
                            .frame(height: 20)
                            .overlay {
                                if isSelected || point.isToday {
                                    RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                                        .strokeBorder(
                                            isSelected ? .white.opacity(0.92) : accent.opacity(0.60),
                                            lineWidth: isSelected ? 1.4 : 0.9
                                        )
                                }
                            }
                            .scaleEffect(growth > 0 ? 1 : 0.84)
                            .opacity(Double(growth))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(point.dateLabel)，\(formatMinutes(point.minutes))")
                }
            }

            HStack(spacing: 6) {
                Text("低")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.36))
                ForEach(0..<4, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(cellColor(level: level, isSelected: false))
                        .frame(width: 11, height: 11)
                }
                Text("高")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.36))
                Spacer()
                Text("近 \(points.count) 天")
                    .font(.custom("GeistMono-Regular", size: 10))
                    .foregroundStyle(.white.opacity(0.36))
            }
        }
    }

    private func intensityLevel(minutes: Double, maxVal: Double) -> Int {
        guard minutes > 0 else { return 0 }
        let ratio = minutes / maxVal
        if ratio >= 0.72 { return 3 }
        if ratio >= 0.35 { return 2 }
        return 1
    }

    private func cellColor(level: Int, isSelected: Bool) -> Color {
        if isSelected { return accent }
        switch level {
        case 0: return .white.opacity(0.055)
        case 1: return .white.opacity(0.24)
        case 2: return .white.opacity(0.56)
        default: return accent.opacity(0.90)
        }
    }

    private func animateGrowth() {
        if reduceMotion {
            growth = 1
            return
        }
        growth = 0.04
        withAnimation(.spring(duration: 0.44, bounce: 0.06)) {
            growth = 1
        }
    }

    private func formatMinutes(_ minutes: Double) -> String {
        if minutes < 0.05 { return "0 分钟" }
        if minutes < 1 { return "\(Int((minutes * 60).rounded())) 秒" }
        if minutes >= 60 {
            let h = Int(minutes) / 60
            let m = Int(minutes) % 60
            return "\(h) 小时 \(m) 分钟"
        }
        return "\(Int(minutes.rounded())) 分钟"
    }
}
