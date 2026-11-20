import XCTest
@testable import Stillroom

final class PlaybackDiagnosticArchiveTests: XCTestCase {
    func testRotatingJournalKeepsCompleteDecodableEventsWithinItsByteBudget() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let archive = PlaybackDiagnosticArchive(directory: root, journalLimit: 1024)
        for index in 0..<40 {
            var entry = entry(.next)
            entry.position = Double(index)
            try await archive.append(entry)
        }
        let files = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.count, 2)
        for file in files {
            let data = try Data(contentsOf: file)
            XCTAssertLessThanOrEqual(data.count, 1024)
            XCTAssertEqual(data.last, 0x0a)
            for line in data.split(separator: 0x0a) {
                _ = try JSONDecoder().decode(PlaybackDiagnosticEntry.self, from: Data(line))
            }
        }
        let latest = try String(contentsOf: root.appendingPathComponent("playback.ndjson"))
            .split(separator: "\n").last.map(String.init)
        let row = try JSONDecoder().decode(PlaybackDiagnosticEntry.self, from: Data(try XCTUnwrap(latest).utf8))
        XCTAssertEqual(row.position, 39)
    }

    func testOversizedSystemPayloadCannotDisplaceExistingBoundedEvidence() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let archive = PlaybackDiagnosticArchive(directory: root, payloadLimit: 512, payloadCount: 2)
        for index in 0..<6 { try await archive.storeSystemDiagnostic(Data("{\"sample\":\(index)}".utf8)) }
        let before = try FileManager.default.contentsOfDirectory(atPath: root.path)
        XCTAssertEqual(before.count, 2)
        do {
            try await archive.storeSystemDiagnostic(Data(repeating: 0, count: 513))
            XCTFail("Oversized system payload must be rejected")
        } catch PlaybackDiagnosticArchive.ArchiveError.payloadTooLarge {}
        let after = try FileManager.default.contentsOfDirectory(atPath: root.path)
        XCTAssertEqual(Set(before), Set(after))
    }

    @MainActor
    func testErrorEvidenceExcludesAuthenticatedURLsAndLocalizedDescriptions() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let recorder = PlaybackDiagnostics(archive: PlaybackDiagnosticArchive(directory: root))
        let secret = "https://private-user:private-password@example.invalid/music?token=secret-token"
        let error = NSError(domain: NSURLErrorDomain, code: -1001,
            userInfo: [NSLocalizedDescriptionKey: secret, NSURLErrorFailingURLErrorKey: URL(string: secret)!])
        await recorder.record(.failure, position: .infinity, playing: false,
                              preparing: false, error: error).value
        let data = try Data(contentsOf: root.appendingPathComponent("playback.ndjson"))
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        for forbidden in ["private-user", "private-password", "example.invalid", "secret-token", "https"] {
            XCTAssertFalse(text.contains(forbidden))
        }
        let decoded = try JSONDecoder().decode(PlaybackDiagnosticEntry.self, from: data)
        XCTAssertEqual(decoded.errorDomain, NSURLErrorDomain)
        XCTAssertEqual(decoded.errorCode, -1001)
        XCTAssertNil(decoded.position)
    }

    func testArchiveFailureCannotReplaceAnExistingLibraryIndex() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let index = root.appendingPathComponent("library.json")
        let original = Data("Unreadable existing user index must remain untouched".utf8)
        try original.write(to: index)
        let archive = PlaybackDiagnosticArchive(directory: index)
        do {
            try await archive.append(entry(.launch))
            XCTFail("A file cannot be used as the diagnostic directory")
        } catch {}
        XCTAssertEqual(try Data(contentsOf: index), original)
    }

    private func entry(_ event: PlaybackDiagnosticEvent) -> PlaybackDiagnosticEntry {
        PlaybackDiagnosticEntry(timestamp: 1, session: "unit-session", processID: 1,
            build: "unit", event: event)
    }
}
