import SwiftUI

/// Reel customization tab offering both universal inner hub gear dyeing (`TeethColour`)
/// and Cassette 1.0.5's 3-style × 7-finish anodized aluminum reel flanges for exposed clear tapes.
struct OneTapeReelCustomization: View {
    @Binding var appearance: OneTapeAppearance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var threeColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            teethSection
            metalReelSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }

    // MARK: - Universal Hub Teeth

    private var teethSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("齿轮", subtitle: "适用于所有磁带")

            HStack(spacing: 12) {
                ForEach(OneTapeAppearance.ReelColor.allCases) { color in
                    teethSwatchButton(for: color)
                }
            }
            .padding(.leading, 2)
        }
    }

    private func teethSwatchButton(for option: OneTapeAppearance.ReelColor) -> some View {
        let isSelected = appearance.reelColor == option
        return Button {
            select { $0.reelColor = option }
        } label: {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [option.highlightColor, option.swatchColor, option.shadowColor],
                            center: .init(x: 0.35, y: 0.30),
                            startRadius: 2,
                            endRadius: 20
                        )
                    )
                    .frame(width: 34, height: 34)
                    .overlay {
                        Circle()
                            .strokeBorder(Color.white.opacity(option == .black ? 0.22 : 0.14), lineWidth: 0.8)
                    }

                if isSelected {
                    Circle()
                        .stroke(Color.white, lineWidth: 1.8)
                        .frame(width: 42, height: 42)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.accessibilityName)
        .accessibilityValue(isSelected ? "已选择" : "")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier("customization.reelColor.\(option.rawValue)")
    }

    // MARK: - Exposed Anodized Metal Flanges

    private var metalReelSection: some View {
        let showsMetal = appearance.tapeStyle.showsExposedMetalReels
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                sectionHeader("金属卷盘", subtitle: showsMetal ? "透黑磁带实时生效" : "适用于透黑磁带")
                Spacer(minLength: 8)
                if !showsMetal {
                    Button {
                        select { $0.selectTapeStyle(.clear) }
                    } label: {
                        Text("切至透黑")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(red: 0.92, green: 0.65, blue: 0.36))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(red: 0.87, green: 0.55, blue: 0.25).opacity(0.16), in: Capsule())
                            .overlay {
                                Capsule()
                                    .strokeBorder(Color(red: 0.87, green: 0.55, blue: 0.25).opacity(0.42), lineWidth: 0.7)
                            }
                            .frame(minHeight: 32)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("切换至透黑磁带预览金属卷盘")
                    .accessibilityIdentifier("customization.reel.switchToClear")
                }
            }

            LazyVGrid(columns: threeColumns, alignment: .leading, spacing: 12) {
                ForEach(OneTapeAppearance.ReelStyle.allCases) { style in
                    OneTapeCustomizationTile(
                        title: style.customizationTitle,
                        selected: appearance.reelStyle == style,
                        studioMarker: style != .classic,
                        identifier: "customization.reelStyle.\(style.rawValue)"
                    ) {
                        select { $0.reelStyle = style }
                    } thumbnail: {
                        OneTapeMetalReelStyleThumb(
                            style: style,
                            finish: appearance.reelFinish,
                            gearColor: appearance.reelColor
                        )
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("卷盘颜色")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.48))
                    Text("·")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.28))
                    Text(appearance.reelFinish.customizationTitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.76))
                }

                ScrollView(.horizontal) {
                    HStack(spacing: 5) {
                        ForEach(OneTapeAppearance.ReelFinish.allCases) { finish in
                            finishSwatchButton(for: finish)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 2)
                }
                .scrollIndicators(.hidden)
                .accessibilityIdentifier("customization.reelFinishes")
            }
            .padding(.top, 2)
        }
    }

    private func finishSwatchButton(for finish: OneTapeAppearance.ReelFinish) -> some View {
        let isSelected = appearance.reelFinish == finish
        return Button {
            select { $0.reelFinish = finish }
        } label: {
            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            gradient: Gradient(stops: finish.anisotropicGradientStops),
                            center: .center,
                            angle: .degrees(-36)
                        )
                    )
                    .frame(width: 30, height: 30)
                    .overlay {
                        Circle()
                            .strokeBorder(finish.rimLight.opacity(0.48), lineWidth: 0.75)
                    }
                    .overlay {
                        // Miniature anodized center spindle hole conveying a metal flange coin.
                        Circle()
                            .fill(Color(white: 0.08))
                            .frame(width: 7, height: 7)
                            .overlay {
                                Circle().stroke(finish.rimLight.opacity(0.42), lineWidth: 0.5)
                            }
                    }

                if isSelected {
                    Circle()
                        .stroke(Color.white, lineWidth: 1.8)
                        .frame(width: 39, height: 39)
                }
            }
            .overlay(alignment: .topTrailing) {
                if finish != .silver {
                    Circle()
                        .fill(Color(red: 0.87, green: 0.56, blue: 0.27))
                        .frame(width: 5.5, height: 5.5)
                        .overlay { Circle().stroke(.black.opacity(0.32), lineWidth: 0.5) }
                        .offset(x: -3, y: 3)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(finish.accessibilityName)
        .accessibilityValue(isSelected ? "已选择" : "")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier("customization.reelFinish.\(finish.rawValue)")
    }

    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.76))
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.white.opacity(0.42))
                .lineLimit(1)
        }
    }

    private func select(_ change: (inout OneTapeAppearance) -> Void) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
            var next = appearance
            change(&next)
            appearance = next
        }
    }
}

/// Live miniature metal flange tile previewing each cutout geometry with the currently
/// chosen anodized finish and center gear hub color over a smoked cassette window.
private struct OneTapeMetalReelStyleThumb: View {
    let style: OneTapeAppearance.ReelStyle
    let finish: OneTapeAppearance.ReelFinish
    let gearColor: OneTapeAppearance.ReelColor?

    var body: some View {
        GeometryReader { geometry in
            let reelDiameter = min(geometry.size.width * 0.56, geometry.size.height * 0.84)
            let hubDiameter = reelDiameter * 0.36
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.14, green: 0.15, blue: 0.165),
                        Color(red: 0.08, green: 0.088, blue: 0.098)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Dark magnetic oxide tape spool sitting behind the cutout slots for contrast.
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.12, green: 0.09, blue: 0.075),
                                Color(red: 0.21, green: 0.155, blue: 0.12),
                                Color(red: 0.14, green: 0.105, blue: 0.085)
                            ],
                            center: .center,
                            startRadius: hubDiameter * 0.45,
                            endRadius: reelDiameter * 0.48
                        )
                    )
                    .frame(width: reelDiameter * 0.90, height: reelDiameter * 0.90)

                OneTapeMetalReelView(
                    diameter: reelDiameter,
                    style: style,
                    finish: finish,
                    angle: .degrees(14)
                )

                OneTapeReelGearView(
                    color: gearColor ?? .white,
                    diameter: hubDiameter,
                    angle: .degrees(14),
                    showsOuterBezel: false,
                    showsAxlePin: true
                )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension OneTapeAppearance.ReelColor {
    var swatchColor: Color {
        switch self {
        case .white: Color(red: 0.922, green: 0.922, blue: 0.922)
        case .black: Color(red: 0.135, green: 0.140, blue: 0.155)
        case .orange: Color(red: 0.980, green: 0.431, blue: 0.118)
        case .crimson: Color(red: 0.820, green: 0.098, blue: 0.278)
        case .blue: Color(red: 0.200, green: 0.424, blue: 0.933)
        }
    }

    var highlightColor: Color {
        switch self {
        case .white: Color(red: 0.985, green: 0.985, blue: 0.985)
        case .black: Color(red: 0.235, green: 0.242, blue: 0.265)
        case .orange: Color(red: 1.000, green: 0.560, blue: 0.240)
        case .crimson: Color(red: 0.930, green: 0.180, blue: 0.370)
        case .blue: Color(red: 0.310, green: 0.550, blue: 0.990)
        }
    }

    var shadowColor: Color {
        switch self {
        case .white: Color(red: 0.680, green: 0.685, blue: 0.695)
        case .black: Color(red: 0.075, green: 0.078, blue: 0.088)
        case .orange: Color(red: 0.720, green: 0.255, blue: 0.045)
        case .crimson: Color(red: 0.555, green: 0.045, blue: 0.165)
        case .blue: Color(red: 0.105, green: 0.245, blue: 0.660)
        }
    }

    var accessibilityName: String {
        switch self {
        case .white: "白色齿轮"
        case .black: "黑色齿轮"
        case .orange: "橙色齿轮"
        case .crimson: "绯红齿轮"
        case .blue: "蓝色齿轮"
        }
    }
}
