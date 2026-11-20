import Foundation

struct MusicCollection: Identifiable, Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable { case album, playlist }
    let id: String
    let kind: Kind
    let title: String
    let subtitle: String
    let remoteID: String
    let trackIDs: [String]
    let coverArtID: String?
    let year: Int?
    let duration: TimeInterval
    var addedAt: Date? = nil

    var songCount: Int { trackIDs.count }
}

struct RemoteTrackReference: Codable, Equatable, Sendable {
    let connectionID: String
    let songID: String
    let albumID: String?
    let coverArtID: String?
}

struct NavidromeConnection: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let baseURL: URL
    let username: String
    /// Identifies an app-owned Keychain item, never a password or signed URL.
    let credentialID: String
}

struct NavidromeCatalog: Codable, Equatable, Sendable {
    let connection: NavidromeConnection
    let tracks: [Track]
    let albums: [MusicCollection]
    let playlists: [MusicCollection]
    let updatedAt: Date
}
