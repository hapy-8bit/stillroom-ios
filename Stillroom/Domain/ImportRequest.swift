import Foundation

enum ImportRequest: Identifiable {
    case music, folder, lyrics(trackID: String), cover(trackID: String, album: Bool)

    var id: String {
        switch self {
        case .music: return "music"
        case .folder: return "folder"
        case .lyrics(let id): return "lyrics-" + id
        case .cover(let id, let album): return "cover-" + id + (album ? "-album" : "-track")
        }
    }
}
