import Foundation
import CryptoKit

enum NavidromeError: LocalizedError {
    case invalidAddress, missingAccount, missingPassword, notConnected
    case network, rejected, server(Int), invalidResponse, tooLarge, corruptCatalog, credentials

    var errorDescription: String? {
        switch self {
        case .invalidAddress: "请填写有效的音乐服务器根地址。"
        case .missingAccount: "请填写服务器用户名。"
        case .missingPassword: "请填写服务器密码。"
        case .notConnected: "请先连接这首音乐所属的服务器。"
        case .network: "无法连接音乐服务器，请检查网络、地址和 HTTPS 证书后重试。"
        case .rejected: "服务器拒绝访问，请检查登录信息和权限。"
        case .server(let code): "服务器未完成请求（代码 \(code)），原曲库已保留。"
        case .invalidResponse: "服务器返回的曲库不完整或格式不正确，原曲库已保留。"
        case .tooLarge: "服务器返回的数据过大，请缩小曲库范围后重试。"
        case .corruptCatalog: "服务器曲库索引无法读取，原文件已保留。"
        case .credentials: "服务器登录信息暂不可用，请重新填写密码连接。"
        }
    }
}

actor NavidromeClient {
    let connection: NavidromeConnection
    private let password: String
    private let session: URLSession

    init(connection: NavidromeConnection, password: String, session: URLSession? = nil) {
        self.connection = connection
        self.password = password
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 60
        configuration.urlCache = nil
        self.session = session ?? URLSession(configuration: configuration)
    }

    static func normalizedAddress(_ address: String) throws -> URL {
        guard var parts = URLComponents(string: address.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = parts.scheme?.lowercased(), ["http", "https"].contains(scheme),
              parts.host?.isEmpty == false, parts.user == nil, parts.password == nil,
              parts.query == nil, parts.fragment == nil else { throw NavidromeError.invalidAddress }
        parts.scheme = scheme
        while parts.path.hasSuffix("/") { parts.path.removeLast() }
        guard let url = parts.url else { throw NavidromeError.invalidAddress }
        return url
    }

    /// Tokens belong to one request URL, not the catalog. Never log this URL:
    /// URLSession errors can contain its authentication query in their userInfo.
    nonisolated func url(_ endpoint: String, parameters: [String: String] = [:], salt: String? = nil) throws -> URL {
        guard endpoint.range(of: "^[A-Za-z][A-Za-z0-9]*$", options: .regularExpression) != nil,
              var parts = URLComponents(url: connection.baseURL, resolvingAgainstBaseURL: false) else {
            throw NavidromeError.invalidAddress
        }
        let salt = salt ?? UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let token = Insecure.MD5.hash(data: Data((password + salt).utf8))
            .map { String(format: "%02x", $0) }.joined()
        parts.path += "/rest/\(endpoint).view"
        var fields = parameters
        fields["u"] = connection.username
        fields["t"] = token
        fields["s"] = salt
        fields["v"] = "1.16.1"
        fields["c"] = "OneTape"
        fields["f"] = "json"
        parts.queryItems = fields.keys.sorted().map { URLQueryItem(name: $0, value: fields[$0]) }
        guard let url = parts.url else { throw NavidromeError.invalidAddress }
        return url
    }

    nonisolated func streamURL(songID: String) throws -> URL {
        // Preserve the original MP3/AAC/FLAC byte stream and its byte ranges.
        // A server-side transcode fallback can be negotiated separately later.
        try url("stream", parameters: ["id": songID, "format": "raw"])
    }

    func ping() async throws { _ = try await json("ping") }

    func fetchCatalog(onProgress: @escaping @MainActor (String) -> Void = { _ in }) async throws -> NavidromeCatalog {
        var albums: [MusicCollection] = []
        var tracks: [Track] = []
        var albumIDs = Set<String>()
        var trackIDs = Set<String>()
        var offset = 0
        while true {
            try Task.checkCancellation()
            let response = try await json("getAlbumList2", parameters: [
                "type": "newest", "size": "100", "offset": String(offset)
            ])
            guard let list = response.albumList2 else { throw NavidromeError.invalidResponse }
            let batch = list.album ?? []
            if batch.isEmpty { break }
            for entry in batch {
                guard !entry.id.isEmpty, albumIDs.insert(entry.id).inserted,
                      albumIDs.count <= 5_000 else { throw NavidromeError.invalidResponse }
            }
            let details = try await Self.boundedMap(batch) { entry in
                let detail = try await self.json("getAlbum", parameters: ["id": entry.id])
                guard let album = detail.album, album.id == entry.id else { throw NavidromeError.invalidResponse }
                return album
            }
            for (index, album) in details.enumerated() {
                let songs = try album.musicTracks(connectionID: connection.id)
                for track in songs {
                    guard trackIDs.insert(track.id).inserted else { throw NavidromeError.invalidResponse }
                    tracks.append(track)
                }
                guard tracks.count <= 20_000 else { throw NavidromeError.tooLarge }
                albums.append(album.collection(connectionID: connection.id, songs: songs,
                                               fallbackCreated: batch[index].created))
                await onProgress("正在整理 \(albums.count) 张专辑 · \(tracks.count) 首音乐")
            }
            // Servers may impose a smaller page size. Only an empty page ends
            // scanning; offset advances by the number actually received.
            offset += batch.count
        }
        let response = try await json("getPlaylists")
        guard let list = response.playlists else { throw NavidromeError.invalidResponse }
        var playlists: [MusicCollection] = []
        let summaries = list.playlist ?? []
        guard summaries.count <= 2_000, Set(summaries.map(\.id)).count == summaries.count else {
            throw NavidromeError.invalidResponse
        }
        // Four simultaneous detail reads bound memory and server load. A batch
        // completes before publication, preserving the server's playlist order.
        for start in stride(from: 0, to: summaries.count, by: 4) {
            try Task.checkCancellation()
            let batch = Array(summaries[start..<min(start + 4, summaries.count)])
            let details = try await Self.boundedMap(batch) { summary in
                let detail = try await self.json("getPlaylist", parameters: ["id": summary.id])
                guard let playlist = detail.playlist, playlist.id == summary.id else { throw NavidromeError.invalidResponse }
                return playlist
            }
            for (index, playlist) in details.enumerated() {
                let entries = try playlist.musicTracks(connectionID: connection.id)
                for track in entries where trackIDs.insert(track.id).inserted { tracks.append(track) }
                playlists.append(playlist.collection(connectionID: connection.id, songs: entries,
                                                     fallbackCreated: batch[index].created))
            }
            guard playlists.count <= 2_000, tracks.count <= 20_000 else { throw NavidromeError.tooLarge }
            await onProgress("已整理 \(albums.count) 张专辑 · 播放列表 \(playlists.count)/\(summaries.count)")
        }
        return NavidromeCatalog(connection: connection, tracks: tracks, albums: albums,
                                playlists: playlists, updatedAt: Date())
    }

    private nonisolated static func boundedMap<Input: Sendable, Output: Sendable>(
        _ inputs: [Input], transform: @escaping @Sendable (Input) async throws -> Output
    ) async throws -> [Output] {
        var output: [Output] = []
        for start in stride(from: 0, to: inputs.count, by: 4) {
            try Task.checkCancellation()
            let end = min(start + 4, inputs.count)
            let batch = try await withThrowingTaskGroup(of: (Int, Output).self) { group in
                for index in start..<end {
                    group.addTask { (index, try await transform(inputs[index])) }
                }
                var results: [(Int, Output)] = []
                for try await result in group { results.append(result) }
                return results.sorted { $0.0 < $1.0 }.map(\.1)
            }
            output.append(contentsOf: batch)
        }
        return output
    }

    func coverArt(id: String) async throws -> Data {
        let (data, response) = try await request("getCoverArt", parameters: ["id": id, "size": "512"], limit: 4 * 1_024 * 1_024)
        guard response.mimeType?.hasPrefix("image/") == true else { throw NavidromeError.invalidResponse }
        return data
    }

    private func json(_ endpoint: String, parameters: [String: String] = [:]) async throws -> SubsonicResponse {
        let (data, _) = try await request(endpoint, parameters: parameters, limit: 8 * 1_024 * 1_024)
        let envelope: SubsonicEnvelope
        do { envelope = try JSONDecoder().decode(SubsonicEnvelope.self, from: data) }
        catch { throw NavidromeError.invalidResponse }
        guard envelope.response.status == "ok" else {
            if [40, 41, 42, 43, 44].contains(envelope.response.error?.code ?? 0) { throw NavidromeError.rejected }
            throw NavidromeError.server(envelope.response.error?.code ?? 0)
        }
        return envelope.response
    }

    private func request(_ endpoint: String, parameters: [String: String], limit: Int) async throws -> (Data, HTTPURLResponse) {
        let address = try url(endpoint, parameters: parameters)
        do {
            let (bytes, response) = try await session.bytes(for: URLRequest(url: address))
            guard let http = response as? HTTPURLResponse else { throw NavidromeError.invalidResponse }
            guard http.statusCode != 401, http.statusCode != 403 else { throw NavidromeError.rejected }
            guard http.statusCode == 200 else { throw NavidromeError.server(http.statusCode) }
            guard response.expectedContentLength <= Int64(limit) else { throw NavidromeError.tooLarge }
            var data = Data()
            for try await byte in bytes {
                if data.count >= limit { throw NavidromeError.tooLarge }
                data.append(byte)
            }
            try Task.checkCancellation()
            guard !data.isEmpty else { throw NavidromeError.invalidResponse }
            return (data, http)
        } catch is CancellationError { throw CancellationError() }
        catch let error as NavidromeError { throw error }
        catch {
            if Task.isCancelled { throw CancellationError() }
            // Do not propagate NSError descriptions containing signed URLs.
            throw NavidromeError.network
        }
    }
}
