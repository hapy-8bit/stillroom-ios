import SwiftUI

enum OneTapeArtworkMode: String, Codable, CaseIterable, Equatable, Sendable {
    case halftone
    case lineInk

    var title: String {
        switch self {
        case .halftone: return "网点照片"
        case .lineInk: return "涂鸦"
        }
    }
}

enum OneTapeHalftoneStyle: String, Codable, CaseIterable, Equatable, Sendable {
    case mono
    case botanical
    case overprint

    var title: String {
        switch self {
        case .mono: return "复古"
        case .botanical: return "植物"
        case .overprint: return "叠印"
        }
    }
}

enum OneTapeArtworkInk: String, Codable, CaseIterable, Identifiable, Equatable, Sendable {
    case tapeInk
    case slate
    case cobalt
    case ruby
    case olive
    case amber
    case emerald

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tapeInk: return "磁带墨色"
        case .slate: return "板岩灰"
        case .cobalt: return "钴蓝"
        case .ruby: return "红宝石"
        case .olive: return "橄榄"
        case .amber: return "琥珀"
        case .emerald: return "祖母绿"
        }
    }

    func rgb(for tapeStyle: OneTapeAppearance.TapeStyle) -> (r: Double, g: Double, b: Double) {
        switch self {
        case .tapeInk:
            return tapeStyle.usesLightInk ? (0.93, 0.91, 0.86) : (0.18, 0.18, 0.19)
        case .slate:
            return (0.34, 0.40, 0.48)
        case .cobalt:
            return (0.15, 0.37, 0.76)
        case .ruby:
            return (0.72, 0.19, 0.23)
        case .olive:
            return (0.35, 0.43, 0.24)
        case .amber:
            return (0.80, 0.49, 0.14)
        case .emerald:
            return (0.12, 0.48, 0.34)
        }
    }

    func swatchColor(for tapeStyle: OneTapeAppearance.TapeStyle) -> Color {
        let c = rgb(for: tapeStyle)
        return Color(red: c.r, green: c.g, blue: c.b)
    }
}

struct OneTapeNormalizedRect: Codable, Equatable, Sendable {
    var x: Double = 0
    var y: Double = 0
    var width: Double = 1
    var height: Double = 1

    static let full = OneTapeNormalizedRect()

    var clamped: OneTapeNormalizedRect {
        let w = min(1.0, max(0.15, width))
        let h = min(1.0, max(0.15, height))
        let x0 = min(1.0 - w, max(0.0, x))
        let y0 = min(1.0 - h, max(0.0, y))
        return OneTapeNormalizedRect(x: x0, y: y0, width: w, height: h)
    }
}

struct OneTapeArtworkPlacement: Codable, Equatable, Sendable {
    var offsetX: Double = 0
    var offsetY: Double = 0
    var scale: Double = 1.0
    var rotationDegrees: Double = 0
    var cropRect: OneTapeNormalizedRect = .full
}

struct OneTapeArtworkRecipe: Codable, Equatable, Sendable {
    var mode: OneTapeArtworkMode = .halftone
    var halftoneStyle: OneTapeHalftoneStyle = .mono
    var primaryInk: OneTapeArtworkInk = .tapeInk
    var secondaryInk: OneTapeArtworkInk = .cobalt
    var subjectOnly: Bool = false
    var cleanup: Double = 0.32
    var dotSize: Double = 0.52
    var inkWear: Double = 0.45
    var strength: Double = 0.65
    var placement: OneTapeArtworkPlacement = .init()
}

struct OneTapeCustomArtwork: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var shellRawValue: String
    var createdAt: Date
    var recipe: OneTapeArtworkRecipe
    var sourceFileName: String
    var subjectMaskFileName: String?
    var printFileName: String
    var thumbFileName: String

    init(
        id: UUID = UUID(),
        shellRawValue: String,
        createdAt: Date = Date(),
        recipe: OneTapeArtworkRecipe,
        sourceFileName: String,
        subjectMaskFileName: String? = nil,
        printFileName: String,
        thumbFileName: String
    ) {
        self.id = id
        self.shellRawValue = shellRawValue
        self.createdAt = createdAt
        self.recipe = recipe
        self.sourceFileName = sourceFileName
        self.subjectMaskFileName = subjectMaskFileName
        self.printFileName = printFileName
        self.thumbFileName = thumbFileName
    }
}

enum OneTapeArtworkError: LocalizedError, Equatable {
    case unreadable
    case noSubjectFound
    case noClearInk
    case saveFailed
    case tooManyPhotos(Int)

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return "无法读取这张图片。请另选一张照片。"
        case .noSubjectFound:
            return "未找到清晰的主体。请关闭“仅保留主体”或另选一张照片。"
        case .noClearInk:
            return "未找到清晰的墨迹。请降低“去杂”、裁剪得更紧，或使用深色笔在浅色素纸上画。"
        case .saveFailed:
            return "无法保存图案。请重试。"
        case .tooManyPhotos(let limit):
            return "你已有 \(limit) 张照片印花。删除一张，为新印花腾出空间。"
        }
    }
}
