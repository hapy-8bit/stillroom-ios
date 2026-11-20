import SwiftUI

/// Pure presentation values: no playback, storage or purchase state belongs to a tonearm.
/// Both current callers share studioSilver. A future picker can pass another tube material;
/// the black carrier and headshell keep their separate, neutral hardware finish.
struct OrbitArmAppearance: Equatable {
    enum Metal: String, CaseIterable {
        case satinSilver, graphite, champagne
    }

    var metal: Metal = .satinSilver
    var accentHex: UInt = 0xB77851
    static let studioSilver = OrbitArmAppearance()

    var accent: Color { color(accentHex) }
    var hardware: Color { color(0x22272A) }
    var hardwareEdge: Color { color(0x62696D) }
    var metalEdge: Color {
        switch metal {
        case .satinSilver: return color(0x747477)
        case .graphite: return color(0x242C31)
        case .champagne: return color(0x685440)
        }
    }
    var metalBody: Color {
        switch metal {
        case .satinSilver: return color(0xB6B6B9)
        case .graphite: return color(0x58646C)
        case .champagne: return color(0xC2A47B)
        }
    }
    var metalLight: Color {
        switch metal {
        case .satinSilver: return color(0xE3E3E4)
        case .graphite: return color(0xA5B1B8)
        case .champagne: return color(0xF3E5CD)
        }
    }
    var machined: [Color] {
        [metalBody, metalLight, metalBody, metalEdge, metalBody, metalLight, metalBody]
    }
    var cylindrical: LinearGradient {
        LinearGradient(stops: [.init(color: metalEdge, location: 0),
                               .init(color: metalBody, location: 0.22),
                               .init(color: metalLight, location: 0.42),
                               .init(color: metalBody, location: 0.65),
                               .init(color: metalEdge, location: 1)],
                       startPoint: .leading, endPoint: .trailing)
    }

    private func color(_ hex: UInt) -> Color {
        Color(.sRGB, red: Double((hex >> 16) & 255) / 255,
              green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}
