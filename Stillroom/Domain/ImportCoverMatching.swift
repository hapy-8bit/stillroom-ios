import Foundation

struct ImportCoverAudio: Sendable {
    let id: UUID
    let directoryID: String
    let albumKey: String
}

enum ImportAlbumCoverSuggestion: Equatable {
    case none, ambiguous, album(UUID)
}

/// A conventional folder image can suggest an album only when every staged
/// song in that exact directory agrees on album identity. Confirmation is
/// still required; unrelated subfolders and mixed albums never inherit it.
enum ImportCoverMatching {
    static func isFolderCover(_ name: String) -> Bool {
        ["cover", "folder"].contains(ImportMediaKind.nameKey(name))
    }

    static func suggest(name: String, directoryID: String, candidates: [ImportCoverAudio],
                        folderCoverCount: Int) -> ImportAlbumCoverSuggestion {
        guard isFolderCover(name), !directoryID.isEmpty else { return .none }
        let local = candidates.filter { $0.directoryID == directoryID }
        guard !local.isEmpty else { return .none }
        guard folderCoverCount == 1, Set(local.map(\.albumKey)).count == 1 else { return .ambiguous }
        return .album(local[0].id)
    }
}
