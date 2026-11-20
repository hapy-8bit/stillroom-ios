import Foundation

/// Disc/track metadata can be a text fraction (ID3) or the big-endian integer
/// tuple used by iTunes. Neither a total count nor a zero is a song position.
enum LocalAudioMetadata {
    static func position(text: String?) -> Int? {
        guard let value = text?.split(separator: "/", omittingEmptySubsequences: false).first,
              let position = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)),
              position > 0, position <= 99_999 else { return nil }
        return position
    }

    static func iTunesPosition(data: Data?) -> Int? {
        guard let data, data.count >= 4 else { return nil }
        let bytes = Array(data.prefix(4))
        let value = Int(bytes[2]) << 8 | Int(bytes[3])
        return value > 0 ? value : nil
    }
}
