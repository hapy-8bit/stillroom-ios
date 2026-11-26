import Foundation
import ImageIO
import UIKit
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Persists the widget snapshot and a downscaled JPEG cover inside the shared
/// App Group container so the WidgetKit extension reads bounded, fresh state.
final class OneTapeWidgetSharedStore: Sendable {
    static let shared = OneTapeWidgetSharedStore()

    private let directoryOverride: URL?
    private let appGroupID: String

    init(
        appGroupID: String = OneTapeWidgetConstants.appGroupID,
        directoryOverride: URL? = nil
    ) {
        self.appGroupID = appGroupID
        self.directoryOverride = directoryOverride
    }

    var containerURL: URL? {
        if let directoryOverride { return directoryOverride }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    var snapshotURL: URL? {
        containerURL?.appendingPathComponent(OneTapeWidgetConstants.snapshotFileName, isDirectory: false)
    }

    var artworkURL: URL? {
        containerURL?.appendingPathComponent(OneTapeWidgetConstants.artworkFileName, isDirectory: false)
    }

    func loadSnapshot() -> OneTapeWidgetSnapshot {
        guard let url = snapshotURL,
              let data = try? Data(contentsOf: url) else { return .empty }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode(OneTapeWidgetSnapshot.self, from: data) else {
            // Preserve unreadable files without overwriting unrelated storage.
            return .empty
        }
        return decoded
    }

    func loadArtwork(maxPixelDimension: Int = 320) -> UIImage? {
        guard let url = artworkURL,
              FileManager.default.fileExists(atPath: url.path),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(64, maxPixelDimension)
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return UIImage(contentsOfFile: url.path)
        }
        return UIImage(cgImage: cgImage)
    }

    @discardableResult
    func save(
        snapshot: OneTapeWidgetSnapshot,
        artwork: UIImage?,
        writeArtwork: Bool
    ) -> Bool {
        guard let directory = containerURL,
              let snapshotURL,
              let artworkURL else { return false }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if writeArtwork {
                if let artwork, let jpeg = Self.downscaledJPEGData(from: artwork, maxPixels: 320) {
                    try jpeg.write(to: artworkURL, options: .atomic)
                } else if FileManager.default.fileExists(atPath: artworkURL.path) {
                    try? FileManager.default.removeItem(at: artworkURL)
                }
            }
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(snapshot)
            try data.write(to: snapshotURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    func reloadTimelines() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: OneTapeWidgetConstants.widgetKind)
        #endif
    }

    private static func downscaledJPEGData(from image: UIImage, maxPixels: CGFloat) -> Data? {
        let sourceSize = image.size
        guard sourceSize.width > 0, sourceSize.height > 0 else { return nil }
        let longest = max(sourceSize.width, sourceSize.height)
        let scale = min(1, maxPixels / longest)
        let targetSize = CGSize(
            width: max(1, (sourceSize.width * scale).rounded()),
            height: max(1, (sourceSize.height * scale).rounded())
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return rendered.jpegData(compressionQuality: 0.84)
    }
}

#if !ONE_TAPE_WIDGET_EXTENSION
/// Coalesces frequent player ticks so the App Group snapshot stays accurate
/// without exhausting WidgetKit's background reload budget.
@MainActor
final class OneTapeWidgetSyncCoordinator {
    static let shared = OneTapeWidgetSyncCoordinator()

    private let store: OneTapeWidgetSharedStore
    private var lastSynced: OneTapeWidgetSnapshot?
    private var lastArtworkID: String?
    private var lastReloadDate: Date = .distantPast

    init(store: OneTapeWidgetSharedStore = .shared) {
        self.store = store
    }

    func sync(snapshot: OneTapeWidgetSnapshot, artwork: UIImage?, force: Bool = false) {
        let structuralChange = lastSynced.map { previous in
            previous.title != snapshot.title
                || previous.artist != snapshot.artist
                || previous.album != snapshot.album
                || previous.trackNumber != snapshot.trackNumber
                || previous.isPlaying != snapshot.isPlaying
                || previous.artworkID != snapshot.artworkID
                || previous.tint != snapshot.tint
        } ?? true

        let artworkChanged = lastArtworkID != snapshot.artworkID || (artwork != nil && lastArtworkID == nil)
        let progressDelta = lastSynced.map { abs($0.clampedProgress - snapshot.clampedProgress) } ?? 1
        let significantSeek = !structuralChange && progressDelta >= 0.02
        let periodicRefresh = snapshot.isPlaying
            && snapshot.updated.timeIntervalSince(lastReloadDate) >= 45

        guard force || structuralChange || artworkChanged || significantSeek || periodicRefresh else {
            return
        }

        if store.save(snapshot: snapshot, artwork: artwork, writeArtwork: artworkChanged || force) {
            lastSynced = snapshot
            lastArtworkID = snapshot.artworkID
            lastReloadDate = snapshot.updated
            store.reloadTimelines()
        }
    }
}
#endif
