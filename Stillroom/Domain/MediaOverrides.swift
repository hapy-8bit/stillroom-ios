import Foundation

/// An optional snapshot distinguishes “not captured yet” from “the source had no embedded artwork”.
/// Effective UI fields may change, while the library index always persists this automatic baseline.
struct AutomaticMediaSnapshot: Codable, Equatable, Sendable {
    var artworkFile: String?
    var lyrics: String
    var isLyricDemo: Bool
}
