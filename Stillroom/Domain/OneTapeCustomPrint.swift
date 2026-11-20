import Foundation
import UIKit

enum OneTapeDrawingInkMode: String, Codable, CaseIterable, Equatable, Sendable {
    case tapeInk
    case originalColors

    var title: String {
        switch self {
        case .tapeInk:
            return "使用磁带墨色"
        case .originalColors:
            return "保留原色"
        }
    }
}

struct OneTapeCustomDrawing: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var shellRawValue: String
    var inkMode: OneTapeDrawingInkMode
    var createdAt: Date
    var imageFileName: String
    var pkDrawingFileName: String?
    var underlayImageFileName: String?
    var thumbFileName: String
    var fromPaperTemplate: Bool = false

    init(
        id: UUID = UUID(),
        shellRawValue: String,
        inkMode: OneTapeDrawingInkMode = .originalColors,
        createdAt: Date = Date(),
        imageFileName: String,
        pkDrawingFileName: String? = nil,
        underlayImageFileName: String? = nil,
        thumbFileName: String,
        fromPaperTemplate: Bool = false
    ) {
        self.id = id
        self.shellRawValue = shellRawValue
        self.inkMode = inkMode
        self.createdAt = createdAt
        self.imageFileName = imageFileName
        self.pkDrawingFileName = pkDrawingFileName
        self.underlayImageFileName = underlayImageFileName
        self.thumbFileName = thumbFileName
        self.fromPaperTemplate = fromPaperTemplate
    }

    var canEditStrokes: Bool {
        pkDrawingFileName != nil
    }
}

struct OneTapeResolvedPrint: Equatable {
    let drawingID: UUID
    let revision: Int
    let image: UIImage
    let inkMode: OneTapeDrawingInkMode

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.drawingID == rhs.drawingID
            && lhs.revision == rhs.revision
            && lhs.inkMode == rhs.inkMode
            && lhs.image === rhs.image
    }
}

struct OneTapeImportedPaper {
    let image: UIImage
    let recognizedPaper: Bool
}

enum OneTapeDrawingPaperError: LocalizedError, Equatable {
    case unreadable
    case noDrawing
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return "无法打开这张图片。请尝试保存为 PNG 或 JPEG。"
        case .noDrawing:
            return "这张图片上没有找到绘画。请用比纸张更深的颜色画，或使用模板。"
        case .saveFailed:
            return "保存画作失败，请重试。"
        }
    }
}

enum OneTapeDrawingGeometry {
    static let cassettePortraitSize = CGSize(width: 376.33, height: 576)
    static let cassetteLandscapeSize = CGSize(width: 576, height: 376.33)
    // 3x portrait canvas keeps vector ink crisp while matching OneTapeBrandPrint coordinates.
    static let storedPortraitPixelSize = CGSize(width: 1129, height: 1728)
    static let thumbnailLandscapePixelSize = CGSize(width: 360, height: 235)
    // Original Cassette paper is generated in landscape 2604x1836 (150px margins around 2304x1536).
    static let paperCanvasPixelSize = CGSize(width: 2604, height: 1836)
    static let paperMarginPixels: CGFloat = 150
}
