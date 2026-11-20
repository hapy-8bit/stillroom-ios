import AVFoundation
import Foundation

struct LocalMetadataReadResult: Sendable {
    var track: Track
    var artworkNotice: String?
}

enum MetadataReader {
    static func read(_ url: URL, id: String, originalName: String, directory: URL) async throws -> Track {
        try await readForPreview(url, id: id, originalName: originalName, directory: directory).track
    }

    static func readForPreview(_ url: URL, id: String, originalName: String,
                               directory: URL) async throws -> LocalMetadataReadResult {
        let asset = AVURLAsset(url: url)
        let playable = try await asset.load(.isPlayable)
        let duration = try await asset.load(.duration).seconds
        guard playable, duration.isFinite, duration > 0 else { throw LibraryError.missingAudio }
        var track = Track(id: id, title: originalName, artist: "未知艺术家", album: originalName,
                          audioFile: url.lastPathComponent, palette: .local, duration: duration,
                          lyrics: "", isDemo: false, isLyricDemo: false)
        let common = (try? await asset.load(.commonMetadata)) ?? []
        let metadata = (try? await asset.load(.metadata)) ?? common
        for item in common {
            switch item.commonKey {
            case .commonKeyTitle: track.title = (try? await item.load(.stringValue))?.nonEmpty ?? track.title
            case .commonKeyArtist: track.artist = (try? await item.load(.stringValue))?.nonEmpty ?? track.artist
            case .commonKeyAlbumName: track.album = (try? await item.load(.stringValue))?.nonEmpty ?? track.album
            default: break
            }
        }
        for item in metadata {
            switch item.identifier {
            case .id3MetadataBand, .iTunesMetadataAlbumArtist:
                track.albumArtist = (try? await item.load(.stringValue))?.nonEmpty ?? track.albumArtist
            case .id3MetadataTrackNumber, .iTunesMetadataTrackNumber:
                track.trackNumber = await position(item) ?? track.trackNumber
            case .id3MetadataPartOfASet, .iTunesMetadataDiscNumber:
                track.discNumber = await position(item) ?? track.discNumber
            default: break
            }
        }
        // A damaged optional image never invalidates playable music. Its
        // explicit preview/result notice offers a later album-cover repair.
        var result = LocalMetadataReadResult(track: track)
        if let artwork = common.first(where: { $0.commonKey == .commonKeyArtwork }) {
            do {
                guard let data = try await artwork.load(.dataValue) else { throw CoverImportError.invalidImage }
                let filename = id + ".jpg"
                try CoverImportAdapter.normalize(data: data, destination: directory.appendingPathComponent(filename))
                result.track.artworkFile = filename
            } catch {
                result.artworkNotice = "内嵌封面未能读取或保存；音乐仍可导入，稍后可添加专辑封面。"
            }
        }
        return result
    }

    private static func position(_ item: AVMetadataItem) async -> Int? {
        if let value = LocalAudioMetadata.position(text: try? await item.load(.stringValue)) { return value }
        if let number = try? await item.load(.numberValue), number.intValue > 0 { return number.intValue }
        return LocalAudioMetadata.iTunesPosition(data: try? await item.load(.dataValue))
    }
}

private extension String {
    var nonEmpty: String? { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self }
}
