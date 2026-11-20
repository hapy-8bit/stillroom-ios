import Foundation

actor NavidromeCatalogRepository {
    let directory: URL
    private var validated = false
    private var readable = true

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Stillroom/Navidrome", isDirectory: true)
    }

    func load() throws -> NavidromeCatalog? {
        let file = directory.appendingPathComponent("catalog.json")
        guard FileManager.default.fileExists(atPath: file.path) else {
            validated = true
            readable = true
            return nil
        }
        do {
            let data = try Data(contentsOf: file)
            guard data.count <= 32 * 1_024 * 1_024 else { throw NavidromeError.corruptCatalog }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let catalog = try decoder.decode(NavidromeCatalog?.self, from: data)
            if let catalog { try validate(catalog) }
            validated = true
            readable = true
            return catalog
        } catch {
            validated = true
            readable = false
            throw NavidromeError.corruptCatalog
        }
    }

    func save(_ catalog: NavidromeCatalog?) throws {
        if !validated { _ = try load() }
        guard readable else { throw NavidromeError.corruptCatalog }
        if let catalog { try validate(catalog) }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(catalog)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: directory.appendingPathComponent("catalog.json"), options: .atomic)
    }

    private func validate(_ catalog: NavidromeCatalog) throws {
        let connection = catalog.connection
        _ = try NavidromeClient.normalizedAddress(connection.baseURL.absoluteString)
        let ids = Set(catalog.tracks.map(\.id))
        guard !connection.id.isEmpty, !connection.credentialID.isEmpty, !connection.username.isEmpty,
              catalog.tracks.count <= 20_000, ids.count == catalog.tracks.count,
              catalog.tracks.allSatisfy({
                  !$0.isDemo && $0.remote?.connectionID == connection.id &&
                  $0.remote?.songID.isEmpty == false && $0.duration.isFinite && $0.duration >= 0
              }),
              catalog.albums.count <= 5_000, catalog.playlists.count <= 2_000,
              (catalog.albums + catalog.playlists).allSatisfy({ Set($0.trackIDs).isSubset(of: ids) }) else {
            throw NavidromeError.corruptCatalog
        }
    }
}
