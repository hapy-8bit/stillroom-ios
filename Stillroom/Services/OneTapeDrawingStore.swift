import Foundation
import PencilKit
import UIKit

@MainActor
final class OneTapeDrawingStore: ObservableObject {
    @Published private(set) var drawings: [OneTapeCustomDrawing] = []
    @Published private(set) var hasCorruptedIndex = false
    @Published private(set) var revision = 0
    @Published var notice: String? = nil

    private let baseDirectory: URL
    private let fileManager: FileManager
    private var fullImageCache: [UUID: UIImage] = [:]
    private var thumbnailCache: [UUID: UIImage] = [:]
    private var archivedCorruptedIndex = false

    init(directory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        if let directory {
            self.baseDirectory = directory
        } else {
            let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            self.baseDirectory = support.appendingPathComponent("OneTapeDrawings", isDirectory: true)
        }
        loadIndex()
    }

    var drawingsDirectory: URL {
        baseDirectory.appendingPathComponent("drawings", isDirectory: true)
    }

    private var indexURL: URL {
        baseDirectory.appendingPathComponent("index.json")
    }

    func drawing(for id: UUID?) -> OneTapeCustomDrawing? {
        guard let id else { return nil }
        return drawings.first(where: { $0.id == id })
    }

    func hasDrawing(id: UUID) -> Bool {
        drawings.contains(where: { $0.id == id })
    }

    func displayTitle(for drawing: OneTapeCustomDrawing) -> String {
        let index = (drawings.firstIndex(where: { $0.id == drawing.id }) ?? 0) + 1
        return "画作 \(index)"
    }

    func resolvedPrint(for appearance: OneTapeAppearance) -> OneTapeResolvedPrint? {
        guard let id = appearance.customDrawingID,
              let item = drawing(for: id),
              let image = portraitImage(for: item) else {
            return nil
        }
        return OneTapeResolvedPrint(
            drawingID: item.id,
            revision: revision,
            image: image,
            inkMode: item.inkMode
        )
    }

    func portraitImage(for drawing: OneTapeCustomDrawing) -> UIImage? {
        if let cached = fullImageCache[drawing.id] {
            return cached
        }
        let url = drawingsDirectory.appendingPathComponent(drawing.imageFileName)
        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            return nil
        }
        fullImageCache[drawing.id] = image
        return image
    }

    func thumbnail(for drawing: OneTapeCustomDrawing) -> UIImage? {
        if let cached = thumbnailCache[drawing.id] {
            return cached
        }
        let url = drawingsDirectory.appendingPathComponent(drawing.thumbFileName)
        if let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            thumbnailCache[drawing.id] = image
            return image
        }
        guard let portrait = portraitImage(for: drawing),
              let regenerated = Self.renderLandscapeThumbnail(fromPortrait: portrait) else {
            return nil
        }
        thumbnailCache[drawing.id] = regenerated
        return regenerated
    }

    func loadPKDrawing(for drawing: OneTapeCustomDrawing) -> PKDrawing? {
        guard let pkName = drawing.pkDrawingFileName else { return nil }
        let url = drawingsDirectory.appendingPathComponent(pkName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? PKDrawing(data: data)
    }

    func loadPortraitUnderlay(for drawing: OneTapeCustomDrawing) -> UIImage? {
        if let underlayName = drawing.underlayImageFileName {
            let url = drawingsDirectory.appendingPathComponent(underlayName)
            if let data = try? Data(contentsOf: url),
               let portraitUnderlay = UIImage(data: data) {
                return portraitUnderlay
            }
        }
        // When tapping "在上面画" on an imported drawing that has no vector strokes yet,
        // keep the imported ink as a persistent underlay beneath new PencilKit strokes.
        if drawing.pkDrawingFileName == nil {
            return portraitImage(for: drawing)
        }
        return nil
    }

    @discardableResult
    func saveCanvasDrawing(
        editingID: UUID? = nil,
        pkDrawing: PKDrawing,
        portraitUnderlay: UIImage? = nil,
        shell: OneTapeAppearance.TapeStyle,
        inkMode: OneTapeDrawingInkMode = .originalColors
    ) throws -> OneTapeCustomDrawing {
        try ensureDirectories()

        let id = editingID ?? UUID()
        let existing = editingID.flatMap { id in drawings.first(where: { $0.id == id }) }
        let logicalPortrait = OneTapeDrawingGeometry.cassettePortraitSize
        let portraitPixelSize = OneTapeDrawingGeometry.storedPortraitPixelSize

        let compositePortrait = Self.renderCompositePortrait(
            pkDrawing: pkDrawing,
            underlay: portraitUnderlay,
            logicalSize: logicalPortrait
        )
        let thumbnailImage = Self.renderLandscapeThumbnail(fromPortrait: compositePortrait)

        guard let portraitData = compositePortrait.pngData(),
              let thumbData = thumbnailImage?.pngData() else {
            throw OneTapeDrawingPaperError.saveFailed
        }

        let imageFileName = "\(id.uuidString).png"
        let thumbFileName = "\(id.uuidString).thumb.png"
        let pkFileName = "\(id.uuidString).pkdrawing"

        try portraitData.write(to: drawingsDirectory.appendingPathComponent(imageFileName), options: .atomic)
        try thumbData.write(to: drawingsDirectory.appendingPathComponent(thumbFileName), options: .atomic)
        try pkDrawing.dataRepresentation().write(to: drawingsDirectory.appendingPathComponent(pkFileName), options: .atomic)

        var underlayFileName = existing?.underlayImageFileName
        if let portraitUnderlay {
            let file = "\(id.uuidString).underlay.png"
            let normalizedUnderlay = Self.renderPortraitImage(portraitUnderlay, targetPixelSize: portraitPixelSize)
            if let underlayData = normalizedUnderlay.pngData() {
                try underlayData.write(to: drawingsDirectory.appendingPathComponent(file), options: .atomic)
                underlayFileName = file
            }
        }

        let saved = OneTapeCustomDrawing(
            id: id,
            shellRawValue: shell.rawValue,
            inkMode: existing?.inkMode ?? inkMode,
            createdAt: existing?.createdAt ?? Date(),
            imageFileName: imageFileName,
            pkDrawingFileName: pkFileName,
            underlayImageFileName: underlayFileName,
            thumbFileName: thumbFileName,
            fromPaperTemplate: existing?.fromPaperTemplate ?? false
        )

        upsert(saved)
        try persistIndex()

        fullImageCache[id] = compositePortrait
        thumbnailCache[id] = thumbnailImage
        revision += 1
        return saved
    }

    @discardableResult
    func saveImportedInk(
        _ imported: OneTapeImportedPaper,
        shell: OneTapeAppearance.TapeStyle,
        inkMode: OneTapeDrawingInkMode
    ) throws -> OneTapeCustomDrawing {
        try ensureDirectories()

        let id = UUID()
        let portraitSize = OneTapeDrawingGeometry.storedPortraitPixelSize
        let normalizedPortrait = Self.renderPortraitImage(imported.image, targetPixelSize: portraitSize)
        let thumbnailImage = Self.renderLandscapeThumbnail(fromPortrait: normalizedPortrait)

        guard let portraitData = normalizedPortrait.pngData(),
              let thumbData = thumbnailImage?.pngData() else {
            throw OneTapeDrawingPaperError.saveFailed
        }

        let imageFileName = "\(id.uuidString).png"
        let thumbFileName = "\(id.uuidString).thumb.png"

        try portraitData.write(to: drawingsDirectory.appendingPathComponent(imageFileName), options: .atomic)
        try thumbData.write(to: drawingsDirectory.appendingPathComponent(thumbFileName), options: .atomic)

        let saved = OneTapeCustomDrawing(
            id: id,
            shellRawValue: shell.rawValue,
            inkMode: inkMode,
            createdAt: Date(),
            imageFileName: imageFileName,
            pkDrawingFileName: nil,
            underlayImageFileName: nil,
            thumbFileName: thumbFileName,
            fromPaperTemplate: imported.recognizedPaper
        )

        upsert(saved)
        try persistIndex()

        fullImageCache[id] = normalizedPortrait
        thumbnailCache[id] = thumbnailImage
        revision += 1
        return saved
    }

    func updateInkMode(id: UUID, inkMode: OneTapeDrawingInkMode) {
        guard let index = drawings.firstIndex(where: { $0.id == id }),
              drawings[index].inkMode != inkMode else {
            return
        }
        drawings[index].inkMode = inkMode
        do {
            try persistIndex()
        } catch {
            notice = error.localizedDescription
        }
        revision += 1
    }

    func deleteDrawing(id: UUID) {
        guard let index = drawings.firstIndex(where: { $0.id == id }) else { return }
        let removed = drawings.remove(at: index)
        fullImageCache.removeValue(forKey: id)
        thumbnailCache.removeValue(forKey: id)

        for fileName in [removed.imageFileName, removed.thumbFileName, removed.pkDrawingFileName, removed.underlayImageFileName].compactMap({ $0 }) {
            let url = drawingsDirectory.appendingPathComponent(fileName)
            try? fileManager.removeItem(at: url)
        }

        do {
            try persistIndex()
        } catch {
            notice = error.localizedDescription
        }
        revision += 1
    }

    private func upsert(_ item: OneTapeCustomDrawing) {
        if let index = drawings.firstIndex(where: { $0.id == item.id }) {
            drawings[index] = item
        } else {
            drawings.append(item)
        }
    }

    private func loadIndex() {
        guard fileManager.fileExists(atPath: indexURL.path) else {
            drawings = []
            return
        }
        do {
            let data = try Data(contentsOf: indexURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            drawings = try decoder.decode([OneTapeCustomDrawing].self, from: data)
            hasCorruptedIndex = false
        } catch {
            // Never delete or overwrite corrupted index records automatically on load.
            drawings = []
            hasCorruptedIndex = true
            notice = "画作索引无法读取，已保留原索引文件。"
        }
    }

    private func ensureDirectories() throws {
        if !fileManager.fileExists(atPath: baseDirectory.path) {
            try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        }
        if !fileManager.fileExists(atPath: drawingsDirectory.path) {
            try fileManager.createDirectory(at: drawingsDirectory, withIntermediateDirectories: true)
        }
    }

    private func persistIndex() throws {
        try ensureDirectories()
        if hasCorruptedIndex && !archivedCorruptedIndex && fileManager.fileExists(atPath: indexURL.path) {
            let backupName = "index.corrupted.\(Int(Date().timeIntervalSince1970)).json"
            let backupURL = baseDirectory.appendingPathComponent(backupName)
            try? fileManager.copyItem(at: indexURL, to: backupURL)
            archivedCorruptedIndex = true
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(drawings)
        try data.write(to: indexURL, options: .atomic)
    }

    // MARK: - Deterministic Coordinate Conversions

    static func renderCompositePortrait(
        pkDrawing: PKDrawing,
        underlay: UIImage?,
        logicalSize: CGSize
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        format.opaque = false
        let bounds = CGRect(origin: .zero, size: logicalSize)
        return UIGraphicsImageRenderer(size: logicalSize, format: format).image { _ in
            underlay?.draw(in: bounds)
            pkDrawing.image(from: bounds, scale: 3).draw(in: bounds)
        }
    }

    // Landscape (576x376.33) -> Portrait (376.33x576, 3x) aligns +90 deg with OneTapeBrandPrint
    // and reverts cleanly to upright under OneTapeTapeThumbnail's -90 deg transform.
    static func rotateClockwise90(_ landscapeImage: UIImage, targetPixelSize: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: targetPixelSize, format: format).image { context in
            let cg = context.cgContext
            cg.translateBy(x: targetPixelSize.width / 2, y: targetPixelSize.height / 2)
            cg.rotate(by: .pi / 2)
            landscapeImage.draw(in: CGRect(
                x: -targetPixelSize.height / 2,
                y: -targetPixelSize.width / 2,
                width: targetPixelSize.height,
                height: targetPixelSize.width
            ))
        }
    }

    static func rotateCounterClockwise90(_ portraitImage: UIImage, targetSize: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        format.opaque = false
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { context in
            let cg = context.cgContext
            cg.translateBy(x: targetSize.width / 2, y: targetSize.height / 2)
            cg.rotate(by: -.pi / 2)
            portraitImage.draw(in: CGRect(
                x: -targetSize.height / 2,
                y: -targetSize.width / 2,
                width: targetSize.height,
                height: targetSize.width
            ))
        }
    }

    static func renderPortraitImage(_ image: UIImage, targetPixelSize: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: targetPixelSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetPixelSize))
        }
    }

    static func renderLandscapeThumbnail(fromLandscape landscapeImage: UIImage) -> UIImage? {
        let thumbSize = OneTapeDrawingGeometry.thumbnailLandscapePixelSize
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: thumbSize, format: format).image { _ in
            landscapeImage.draw(in: CGRect(origin: .zero, size: thumbSize))
        }
    }

    static func renderLandscapeThumbnail(fromPortrait portraitImage: UIImage) -> UIImage? {
        let thumbSize = OneTapeDrawingGeometry.thumbnailLandscapePixelSize
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: thumbSize, format: format).image { context in
            let cg = context.cgContext
            cg.translateBy(x: thumbSize.width / 2, y: thumbSize.height / 2)
            cg.rotate(by: -.pi / 2)
            portraitImage.draw(in: CGRect(
                x: -thumbSize.height / 2,
                y: -thumbSize.width / 2,
                width: thumbSize.height,
                height: thumbSize.width
            ))
        }
    }
}
