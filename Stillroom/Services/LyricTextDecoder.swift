import Foundation

enum LyricTextEncoding: String, Sendable { case utf8 = "utf-8", utf16LE = "utf-16le", utf16BE = "utf-16be" }
enum LyricEncodingRequest: Sendable { case auto, utf8, utf16LE, utf16BE, gbk, gb18030 }
struct DecodedLyricText: Sendable { let text: String; let encoding: LyricTextEncoding }

enum LyricTextDecoder {
    /// Caller supplies already-authorized bytes. Auto mode recognizes BOMs then strictly tries UTF-8;
    /// no legacy Chinese page or BOM-less UTF-16 guess may silently replace characters.
    static func decode(_ data: Data, encoding requested: LyricEncodingRequest = .auto) throws -> DecodedLyricText {
        guard !data.isEmpty else { throw LyricImportError.empty }
        guard data.count <= 1_048_576 else { throw LyricImportError.tooLarge }
        if requested == .gbk || requested == .gb18030 { throw LyricImportError.unsupportedEncoding }
        let bytes = [UInt8](data)
        if bytes.starts(with: [255, 254, 0, 0]) || bytes.starts(with: [0, 0, 254, 255]) { throw LyricImportError.unsupportedEncoding }
        var detected: LyricTextEncoding?, start = 0
        if bytes.starts(with: [239, 187, 191]) { detected = .utf8; start = 3 }
        else if bytes.starts(with: [255, 254]) { detected = .utf16LE; start = 2 }
        else if bytes.starts(with: [254, 255]) { detected = .utf16BE; start = 2 }
        let explicit: LyricTextEncoding? = requested == .auto ? nil : requested == .utf16LE ? .utf16LE : requested == .utf16BE ? .utf16BE : .utf8
        if let detected, let explicit, detected != explicit { throw LyricImportError.encodingConflict }
        let encoding = detected ?? explicit ?? .utf8
        let payload = Array(bytes.dropFirst(start))
        let text: String
        if encoding == .utf8 {
            guard let decoded = String(data: Data(payload), encoding: .utf8) else { throw LyricImportError.invalidEncoding }
            text = decoded
        } else {
            guard payload.count.isMultiple(of: 2) else { throw LyricImportError.invalidEncoding }
            var units: [UInt16] = []
            for index in stride(from: 0, to: payload.count, by: 2) {
                let first = UInt16(payload[index]), second = UInt16(payload[index + 1])
                units.append(encoding == .utf16LE ? first | second << 8 : first << 8 | second)
            }
            var index = 0
            while index < units.count {
                if (0xD800...0xDBFF).contains(units[index]) {
                    guard index + 1 < units.count, (0xDC00...0xDFFF).contains(units[index + 1]) else { throw LyricImportError.invalidEncoding }
                    index += 2
                } else {
                    guard !(0xDC00...0xDFFF).contains(units[index]) else { throw LyricImportError.invalidEncoding }
                    index += 1
                }
            }
            // Validating the surrogate pairs first prevents String(decoding:) from introducing replacement glyphs.
            text = String(decoding: units, as: UTF16.self)
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw LyricImportError.empty }
        guard !text.contains("\0") else { throw LyricImportError.invalidEncoding }
        return DecodedLyricText(text: text, encoding: encoding)
    }
}
