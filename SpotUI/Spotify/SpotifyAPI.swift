import Foundation

enum SpotifyAPI {
    static var accessToken: String?

    struct SpotifyError: Error, LocalizedError {
        let statusCode: Int
        let message: String
        var errorDescription: String? { "\(statusCode): \(message)" }
    }

    static func me() async throws -> SpotifyUser {
        try await restGet("me")
    }

    static func lyrics(trackId: String) async throws -> SpotifyLyrics {
        guard let token = accessToken else { throw SpotifyError(statusCode: 401, message: "Not authenticated") }
        let urlString = "https://spclient.wg.spotify.com/color-lyrics/v2/track/\(trackId)?format=json&vocalRemoval=false&market=from_token"
        let data = try await getData(urlString, token: token)
        let root = try parseJSON(data)
        guard let lyricsObj = root["lyrics"] as? JSONObject else {
            throw SpotifyError(statusCode: 500, message: "Invalid lyrics response")
        }
        let synced = lyricsObj["syncType"] as? String == "LINE_SYNCED"
        let lines = (lyricsObj["lines"] as? [JSONObject])?.compactMap { line -> SpotifyLyricLine? in
            guard let words = line["words"] as? String, !words.isEmpty, words != "♪" else { return nil }
            return SpotifyLyricLine(startMs: Int64(line["startTimeMs"] as? String ?? "0") ?? 0, words: words)
        } ?? []
        if lines.isEmpty { throw SpotifyError(statusCode: 404, message: "No lyrics") }
        return SpotifyLyrics(synced: synced, lines: lines)
    }

    static func myPlaylists(limit: Int = 50, offset: Int = 0) async throws -> SpotifyPaging<SpotifyPlaylist> {
        try await restGet("me/playlists?limit=\(limit)&offset=\(offset)")
    }

    static func playlist(_ playlistId: String) async throws -> SpotifyPlaylist {
        try await restGet("playlists/\(playlistId)")
    }

    static func playlistTracks(playlistId: String, limit: Int = 100, offset: Int = 0) async throws -> SpotifyPaging<SpotifyPlaylistTrack> {
        try await restGet("playlists/\(playlistId)/tracks?limit=\(limit)&offset=\(offset)")
    }

    static func likedSongs(limit: Int = 50, offset: Int = 0) async throws -> SpotifyPaging<SpotifySavedTrack> {
        try await restGet("me/tracks?limit=\(limit)&offset=\(offset)")
    }

    static func addToLibrary(uris: [String]) async throws {
        guard let token = accessToken else { throw SpotifyError(statusCode: 401, message: "Not authenticated") }
        let body: JSONObject = ["ids": uris.map { $0.components(separatedBy: ":").last ?? "" }]
        let data = try JSONSerialization.data(withJSONObject: body)
        _ = try await postRaw("me/tracks", body: data, token: token)
    }

    static func removeFromLibrary(uris: [String]) async throws {
        guard let token = accessToken else { throw SpotifyError(statusCode: 401, message: "Not authenticated") }
        let ids = uris.map { $0.components(separatedBy: ":").last ?? "" }
        _ = try await deleteRaw("me/tracks?ids=\(ids.joined(separator: ","))", token: token)
    }

    static func album(_ albumId: String) async throws -> SpotifyAlbum { try await restGet("albums/\(albumId)") }

    static func albumTracks(albumId: String, limit: Int = 50, offset: Int = 0) async throws -> SpotifyPaging<SpotifyTrack> {
        try await restGet("albums/\(albumId)/tracks?limit=\(limit)&offset=\(offset)")
    }

    static func artist(_ artistId: String) async throws -> SpotifyArtist { try await restGet("artists/\(artistId)") }

    static func artistTopTracks(artistId: String, market: String = "US") async throws -> [SpotifyTrack] {
        let data = try await getData(restBase + "artists/\(artistId)/top-tracks?market=\(market)", token: accessToken ?? "")
        let json = try parseJSON(data)
        return (json["tracks"] as? [JSONObject] ?? []).compactMap { try? JSONDecoder().decode(SpotifyTrack.self, from: JSONSerialization.data(withJSONObject: $0)) }
    }

    static func artistAlbums(artistId: String, limit: Int = 20) async throws -> SpotifyPaging<SpotifyAlbum> {
        try await restGet("artists/\(artistId)/albums?limit=\(limit)&include_groups=album,single,compilation")
    }

    static func search(query: String, types: String = "track,album,artist,show,episode", limit: Int = 20) async throws -> SpotifySearchResult {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await restGet("search?q=\(encoded)&type=\(types)&limit=\(limit)")
    }

    static func recommendations(seedTracks: [String], limit: Int = 20) async throws -> SpotifyRecommendations {
        try await restGet("recommendations?seed_tracks=\(seedTracks.prefix(5).joined(separator: ","))&limit=\(limit)")
    }

    static func track(_ trackId: String) async throws -> SpotifyTrack { try await restGet("tracks/\(trackId)") }

    // MARK: - Private

    private static let restBase = "https://api.spotify.com/v1/"

    private static func restGet<T: Decodable>(_ endpoint: String) async throws -> T {
        guard let token = accessToken else { throw SpotifyError(statusCode: 401, message: "Not authenticated") }
        let urlString = endpoint.hasPrefix("http") ? endpoint : restBase + endpoint
        let data = try await getData(urlString, token: token)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func getData(_ urlString: String, token: String) async throws -> Data {
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SpotifyError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1, message: "HTTP error")
        }
        return data
    }

    private static func postRaw(_ endpoint: String, body: Data, token: String) async throws -> Data {
        guard let url = URL(string: restBase + endpoint) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SpotifyError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1, message: "HTTP error")
        }
        return data
    }

    private static func deleteRaw(_ endpoint: String, token: String) async throws -> Data {
        guard let url = URL(string: restBase + endpoint) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SpotifyError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1, message: "HTTP error")
        }
        return data
    }

    private static func parseJSON(_ data: Data) throws -> JSONObject {
        guard let obj = try JSONSerialization.jsonObject(with: data) as? JSONObject else {
            throw NSError(domain: "JSON", code: -1, userInfo: nil)
        }
        return obj
    }
}

typealias JSONObject = [String: Any]
