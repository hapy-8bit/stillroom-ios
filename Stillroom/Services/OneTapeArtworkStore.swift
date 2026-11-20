import Foundation
import UIKit

@MainActor
final class OneTapeArtworkStore: ObservableObject {
    static let maxArtworkCount = 8

    @Published private(set) var artworks: [OneTapeCustomArtwork] = []
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
            self.baseDirectory = support.appendingPathComponent("OneTapeArtworks", isDirectory: true)
        }
        loadIndex()
    }

    var artworksDirectory: URL {
        baseDirectory.appendingPathComponent("artworks", isDirectory: true)
    }

    private var indexURL: URL {
        baseDirectory.appendingPathComponent("index.json")
    }

    var isAtCapacity: Bool {
        artworks.count >= Self.maxArtworkCount
    }

    func artwork(for id: UUID?) -> OneTapeCustomArtwork? {
        guard let id else { return nil }
        return artworks.first(where: { $0.id == id })
    }

    func hasArtwork(id: UUID) -> Bool {
        artworks.contains(where: { $0.id == id })
    }

    func displayTitle(for item: OneTapeCustomArtwork) -> String {
        let index = (artworks.firstIndex(where: { $0.id == item.id }) ?? 0) + 1
        return "照片 \(index)"
    }

    func resolvedPrint(for appearance: OneTapeAppearance) -> OneTapeResolvedPrint? {
        guard let id = appearance.customArtworkID,
              let item = artwork(for: id),
              let image = printImage(for: item) else {
            return nil
        }
        // Halftone and line-ink files are pre-rendered in full resolved ink RGBA colors.
        return OneTapeResolvedPrint(
            drawingID: item.id,
            revision: revision,
            image: image,
            inkMode: .originalColors
        )
    }

    func printImage(for artwork: OneTapeCustomArtwork) -> UIImage? {
        if let cached = fullImageCache[artwork.id] {
            return cached
        }
        let url = artworksDirectory.appendingPathComponent(artwork.printFileName)
        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            return nil
        }
        fullImageCache[artwork.id] = image
        return image
    }

    func thumbnail(for artwork: OneTapeCustomArtwork) -> UIImage? {
        if let cached = thumbnailCache[artwork.id] {
            return cached
        }
        let url = artworksDirectory.appendingPathComponent(artwork.thumbFileName)
        if let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            thumbnailCache[artwork.id] = image
            return image
        }
        guard let portrait = printImage(for: artwork),
              let regenerated = OneTapeDrawingStore.renderLandscapeThumbnail(fromPortrait: portrait) else {
            return nil
        }
        thumbnailCache[artwork.id] = regenerated
        return regenerated
    }

    func loadSourceImage(for artwork: OneTapeCustomArtwork) -> UIImage? {
        let url = artworksDirectory.appendingPathComponent(artwork.sourceFileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func loadSubjectMaskImage(for artwork: OneTapeCustomArtwork) -> UIImage? {
        guard let maskName = artwork.subjectMaskFileName else { return nil }
        let url = artworksDirectory.appendingPathComponent(maskName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    @discardableResult
    func saveArtwork(
        editingID: UUID? = nil,
        sourceImage: UIImage,
        subjectMaskImage: UIImage?,
        renderedPrint: UIImage,
        recipe: OneTapeArtworkRecipe,
        shell: OneTapeAppearance.TapeStyle
    ) throws -> OneTapeCustomArtwork {
        if editingID == nil && artworks.count >= Self.maxArtworkCount {
            throw OneTapeArtworkError.tooManyPhotos(artworks.count)
        }
        try ensureDirectories()

        let id = editingID ?? UUID()
        let existing = editingID.flatMap { targetID in artworks.first(where: { $0.id == targetID }) }
        let normalizedPrint = OneTapeDrawingStore.renderPortraitImage(
            renderedPrint,
            targetPixelSize: OneTapeDrawingGeometry.storedPortraitPixelSize
        )
        let thumbnailImage = OneTapeDrawingStore.renderLandscapeThumbnail(fromPortrait: normalizedPrint)

        guard let printData = normalizedPrint.pngData(),
              let thumbData = thumbnailImage?.pngData() else {
            throw OneTapeArtworkError.saveFailed
        }

        let sourceFileName = "\(id.uuidString).src.jpg"
        let printFileName = "\(id.uuidString).print.png"
        let thumbFileName = "\(id.uuidString).thumb.png"

        let sourceURL = artworksDirectory.appendingPathComponent(sourceFileName)
        if !fileManager.fileExists(atPath: sourceURL.path) || editingID == nil {
            guard let sourceData = sourceImage.jpegData(compressionQuality: 0.90) else {
                throw OneTapeArtworkError.saveFailed
            }
            try sourceData.write(to: sourceURL, options: .atomic)
        }

        var subjectMaskFileName = existing?.subjectMaskFileName
        if let subjectMaskImage {
            let file = "\(id.uuidString).subject.png"
            let maskURL = artworksDirectory.appendingPathComponent(file)
            if !fileManager.fileExists(atPath: maskURL.path) || editingID != nil {
                if let maskData = subjectMaskImage.pngData() {
                    try maskData.write(to: maskURL, options: .atomic)
                    subjectMaskFileName = file
                }
            }
        }

        try printData.write(to: artworksDirectory.appendingPathComponent(printFileName), options: .atomic)
        try thumbData.write(to: artworksDirectory.appendingPathComponent(thumbFileName), options: .atomic)

        let saved = OneTapeCustomArtwork(
            id: id,
            shellRawValue: shell.rawValue,
            createdAt: existing?.createdAt ?? Date(),
            recipe: recipe,
            sourceFileName: sourceFileName,
            subjectMaskFileName: subjectMaskFileName,
            printFileName: printFileName,
            thumbFileName: thumbFileName
        )

        upsert(saved)
        try persistIndex()

        fullImageCache[id] = normalizedPrint
        thumbnailCache[id] = thumbnailImage
        revision += 1
        return saved
    }

    @discardableResult
    func reprintArtwork(id: UUID, for shell: OneTapeAppearance.TapeStyle) throws -> OneTapeCustomArtwork {
        guard let item = artwork(for: id),
              let sourceImage = loadSourceImage(for: item) else {
            throw OneTapeArtworkError.unreadable
        }
        let subjectImage = loadSubjectMaskImage(for: item)
        let rendered = try OneTapeHalftoneEngine.renderArtworkPrint(
            sourceImage: sourceImage,
            subjectMaskImage: subjectImage,
            recipe: item.recipe,
            shell: shell,
            targetSize: OneTapeHalftoneEngine.finalExportSize
        )
        return try saveArtwork(
            editingID: id,
            sourceImage: sourceImage,
            subjectMaskImage: subjectImage,
            renderedPrint: rendered,
            recipe: item.recipe,
            shell: shell
        )
    }

    func deleteArtwork(id: UUID) {
        guard let index = artworks.firstIndex(where: { $0.id == id }) else { return }
        let removed = artworks.remove(at: index)
        fullImageCache.removeValue(forKey: id)
        thumbnailCache.removeValue(forKey: id)

        for name in [removed.sourceFileName, removed.subjectMaskFileName, removed.printFileName, removed.thumbFileName].compactMap({ $0 }) {
            let url = artworksDirectory.appendingPathComponent(name)
            try? fileManager.removeItem(at: url)
        }

        do {
            try persistIndex()
        } catch {
            notice = error.localizedDescription
        }
        revision += 1
    }

    private func upsert(_ item: OneTapeCustomArtwork) {
        if let index = artworks.firstIndex(where: { $0.id == item.id }) {
            artworks[index] = item
        } else {
            artworks.append(item)
        }
    }

    private func loadIndex() {
        guard fileManager.fileExists(atPath: indexURL.path) else {
            artworks = []
            return
        }
        do {
            let data = try Data(contentsOf: indexURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            artworks = try decoder.decode([OneTapeCustomArtwork].self, from: data)
            hasCorruptedIndex = false
        } catch {
            // Never delete or overwrite corrupted records on load.
            artworks = []
            hasCorruptedIndex = true
            notice = "无法打开已保存的图案。你可以重新印制照片。"
        }
    }

    private func ensureDirectories() throws {
        if !fileManager.fileExists(atPath: baseDirectory.path) {
            try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        }
        if !fileManager.fileExists(atPath: artworksDirectory.path) {
            try fileManager.createDirectory(at: artworksDirectory, withIntermediateDirectories: true)
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
        let data = try encoder.encode(artworks)
        try data.write(to: indexURL, options: .atomic)
    }
}
