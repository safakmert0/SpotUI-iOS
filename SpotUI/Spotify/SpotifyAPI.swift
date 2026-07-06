import Foundation

/// Spotify API client — GraphQL + REST fallback.
/// Port of Spotify.kt — handles all Spotify Web API calls.
enum SpotifyAPI {
    static var accessToken: String?

    private static let gqlURL = "https://api-partner.spotify.com/pathfinder/v2/query"
    private static let restBase = "https://api.spotify.com/v1/"

    // MARK: - Errors

    struct SpotifyError: Error, LocalizedError {
        let statusCode: Int
        let message: String
        var errorDescription: String? { "\(statusCode): \(message)" }
    }

    // MARK: - User Profile

    static func me() async throws -> SpotifyUser {
        do {
            let response = try await gqlRequest(operation: "profileAttributes")
            guard let profile = nestedJSON(response, keys: "data", "me", "profile") else {
                throw SpotifyError(statusCode: 500, message: "Invalid profileAttributes response")
            }
            let uri = profile["uri"] as? String ?? ""
            let avatar = nestedJSON(profile, keys: "avatar", "sources")
            return SpotifyUser(
                id: String(uri.split(separator: ":").last ?? ""),
                displayName: profile["name"] as? String,
                email: nil,
                images: parseGqlImages(avatar),
                product: nil, country: nil
            )
        } else {
            return try await restGet("me")
        }
    }

    // MARK: - Lyrics

    static func lyrics(trackId: String) async throws -> SpotifyLyrics {
        guard let token = accessToken else { throw SpotifyError(statusCode: 401, message: "Not authenticated") }
        let urlString = "https://spclient.wg.spotify.com/color-lyrics/v2/track/\(trackId)?format=json&vocalRemoval=false&market=from_token"
        let data = try await getData(urlString, token: token)
        let root = try parseJSON(data)
        guard let lyricsObj = root["lyrics"] as? JSONObject else {
            throw SpotifyError(statusCode: 500, message: "Invalid color-lyrics response")
        }
        let synced = lyricsObj["syncType"] as? String == "LINE_SYNCED"
        let lines = (lyricsObj["lines"] as? [JSONObject])?.compactMap { line -> SpotifyLyricLine? in
            guard let words = line["words"] as? String, !words.isEmpty, words != "♪" else { return nil }
            return SpotifyLyricLine(startMs: Int64(line["startTimeMs"] as? String ?? "0") ?? 0, words: words)
        } ?? []
        if lines.isEmpty { throw SpotifyError(statusCode: 404, message: "Empty lyrics for \(trackId)") }
        return SpotifyLyrics(synced: synced, lines: lines)
    }

    // MARK: - Playlists

    static func myPlaylists(limit: Int = 50, offset: Int = 0) async throws -> SpotifyPaging<SpotifyPlaylist> {
        let vars: JSONObject = ["filters": ["Playlists"], "order": NSNull(), "textFilter": "", "features": ["LIKED_SONGS", "YOUR_EPISODES_V2", "PRERELEASES", "EVENTS"], "limit": limit, "offset": offset, "flatten": true, "expandedFolders": [], "folderUri": NSNull(), "includeFoldersWhenFlattening": false]
        let response = try await gqlRequest(operation: "libraryV3", variables: vars)
        guard let libraryData = nestedJSON(response, keys: "data", "me", "libraryV3") else {
            throw SpotifyError(statusCode: 500, message: "Invalid libraryV3 response")
        }
        let totalCount = libraryData["totalCount"] as? Int ?? 0
        let rawItems = libraryData["items"] as? [JSONObject] ?? []
        let playlists = rawItems.compactMap { item -> SpotifyPlaylist? in
            guard let wrapper = item["item"] as? JSONObject else { return nil }
            let typeName = wrapper["__typename"] as? String ?? ""
            guard typeName == "PlaylistResponseWrapper" || typeName.lowercased().contains("playlist") else { return nil }
            return parsePlaylistWrapper(wrapper)
        }
        return SpotifyPaging(items: playlists, total: totalCount)
    }

    static func playlist(_ playlistId: String) async throws -> SpotifyPlaylist {
        let vars: JSONObject = ["uri": "spotify:playlist:\(playlistId)", "offset": 0, "limit": 25, "enableWatchFeedEntrypoint": true]
        let response = try await gqlRequest(operation: "fetchPlaylist", variables: vars)
        guard let pl = nestedJSON(response, keys: "data", "playlistV2") else {
            throw SpotifyError(statusCode: 500, message: "Invalid fetchPlaylist response")
        }
        let ownerData = nestedJSON(pl, keys: "ownerV2", "data")
        let ownerUri = ownerData?["uri"] as? String ?? ""
        let contentTotal = nestedJSON(pl, keys: "content")?["totalCount"] as? Int ?? 0
        return SpotifyPlaylist(
            id: playlistId, name: pl["name"] as? String ?? "", description: pl["description"] as? String,
            images: parseGqlPlaylistImages(pl["images"]),
            owner: SpotifyPlaylistOwner(id: String(ownerUri.split(separator: ":").last ?? ""), displayName: ownerData?["name"] as? String, uri: ownerUri.isEmpty ? nil : ownerUri),
            tracks: SpotifyPlaylistTracksRef(total: contentTotal), uri: "spotify:playlist:\(playlistId)", public: nil, collaborative: false, snapshotId: nil
        )
    }

    static func playlistTracks(playlistId: String, limit: Int = 100, offset: Int = 0) async throws -> SpotifyPaging<SpotifyPlaylistTrack> {
        let vars: JSONObject = ["uri": "spotify:playlist:\(playlistId)", "offset": offset, "limit": limit, "enableWatchFeedEntrypoint": false]
        let response = try await gqlRequest(operation: "fetchPlaylist", variables: vars)
        guard let content = nestedJSON(response, keys: "data", "playlistV2", "content") else {
            throw SpotifyError(statusCode: 500, message: "No content in fetchPlaylist response")
        }
        let tracks = (content["items"] as? [JSONObject] ?? []).compactMap { elem -> SpotifyPlaylistTrack? in
            guard let itemWrapper = elem["itemV2"] as? JSONObject, let itemData = itemWrapper["data"] as? JSONObject else { return nil }
            let wrapperUri = itemWrapper["_uri"] as? String ?? itemWrapper["uri"] as? String
            let uid = elem["uid"] as? String ?? itemWrapper["uid"] as? String
            return SpotifyPlaylistTrack(track: parseGqlTrack(itemData, uriOverride: wrapperUri), uid: uid)
        }
        return SpotifyPaging(items: tracks, total: content["totalCount"] as? Int ?? 0, limit: limit, offset: offset)
    }

    // MARK: - Liked Songs

    static func likedSongs(limit: Int = 50, offset: Int = 0) async throws -> SpotifyPaging<SpotifySavedTrack> {
        let vars: JSONObject = ["offset": offset, "limit": limit]
        let response = try await gqlRequest(operation: "fetchLibraryTracks", variables: vars)
        guard let tracksData = nestedJSON(response, keys: "data", "me", "library", "tracks") else {
            throw SpotifyError(statusCode: 500, message: "Invalid fetchLibraryTracks response")
        }
        let savedTracks = (tracksData["items"] as? [JSONObject] ?? []).compactMap { elem -> SpotifySavedTrack? in
            guard let trackWrapper = elem["track"] as? JSONObject, let trackData = trackWrapper["data"] as? JSONObject else { return nil }
            let wrapperUri = trackWrapper["_uri"] as? String ?? trackWrapper["uri"] as? String
            return SpotifySavedTrack(track: parseGqlTrack(trackData, uriOverride: wrapperUri))
        }
        return SpotifyPaging(items: savedTracks, total: tracksData["totalCount"] as? Int ?? 0, limit: limit, offset: offset)
    }

    // MARK: - Library Mutations

    static func addToLibrary(uris: [String]) async throws {
        _ = try await gqlRequest(operation: "addToLibrary", variables: ["libraryItemUris": uris])
    }

    static func removeFromLibrary(uris: [String]) async throws {
        _ = try await gqlRequest(operation: "removeFromLibrary", variables: ["libraryItemUris": uris])
    }

    // MARK: - Album

    static func album(_ albumId: String) async throws -> SpotifyAlbum { try await restGet("albums/\(albumId)") }

    static func albumTracks(albumId: String, limit: Int = 50, offset: Int = 0) async throws -> SpotifyPaging<SpotifyTrack> {
        try await restGet("albums/\(albumId)/tracks?limit=\(limit)&offset=\(offset)")
    }

    // MARK: - Artist

    static func artist(_ artistId: String) async throws -> SpotifyArtist { try await restGet("artists/\(artistId)") }

    static func artistTopTracks(artistId: String, market: String = "US") async throws -> [SpotifyTrack] {
        let data = try await getData(restBase + "artists/\(artistId)/top-tracks?market=\(market)", token: accessToken ?? "")
        let json = try parseJSON(data)
        return (json["tracks"] as? [JSONObject] ?? []).compactMap { try? JSONDecoder().decode(SpotifyTrack.self, from: JSONSerialization.data(withJSONObject: $0)) }
    }

    static func artistAlbums(artistId: String, limit: Int = 20) async throws -> SpotifyPaging<SpotifyAlbum> {
        try await restGet("artists/\(artistId)/albums?limit=\(limit)&include_groups=album,single,compilation")
    }

    // MARK: - Search

    static func search(query: String, types: String = "track,album,artist,show,episode", limit: Int = 20) async throws -> SpotifySearchResult {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await restGet("search?q=\(encoded)&type=\(types)&limit=\(limit)")
    }

    // MARK: - Recommendations

    static func recommendations(seedTracks: [String], limit: Int = 20) async throws -> SpotifyRecommendations {
        try await restGet("recommendations?seed_tracks=\(seedTracks.prefix(5).joined(separator: ","))&limit=\(limit)")
    }

    // MARK: - Track

    static func track(_ trackId: String) async throws -> SpotifyTrack { try await restGet("tracks/\(trackId)") }

    // MARK: - Private GraphQL

    private static func gqlRequest(operation: String, variables: JSONObject = [:]) async throws -> JSONObject {
        guard let token = accessToken else { throw SpotifyError(statusCode: 401, message: "Not authenticated") }
        let body: JSONObject = ["variables": variables, "operationName": operation, "extensions": ["persistedQuery": ["version": 1, "sha256Hash": SpotifyHashProvider.hash(for: operation) ?? ""]]]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let headers = ["Authorization": "Bearer \(token)", "User-Agent": randomUserAgent(), "app-platform": "WebPlayer", "Origin": "https://open.spotify.com", "Referer": "https://open.spotify.com/", "Accept": "application/json"]
        let data = try await postRaw(gqlURL, body: bodyData, headers: headers)
        return try parseJSON(data)
    }

    // MARK: - Private REST

    private static func restGet<T: Decodable>(_ endpoint: String) async throws -> T {
        guard let token = accessToken else { throw SpotifyError(statusCode: 401, message: "Not authenticated") }
        let urlString = endpoint.hasPrefix("http") ? endpoint : restBase + endpoint
        let data = try await getData(urlString, token: token)
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - HTTP helpers

    private static func getData(_ urlString: String, token: String) async throws -> Data {
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(randomUserAgent(), forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SpotifyError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1, message: "HTTP error")
        }
        return data
    }

    private static func postRaw(_ urlString: String, body: Data, headers: [String: String]) async throws -> Data {
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SpotifyError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1, message: "HTTP error")
        }
        return data
    }

    // MARK: - JSON helpers

    private static func parseJSON(_ data: Data) throws -> JSONObject {
        guard let obj = try JSONSerialization.jsonObject(with: data) as? JSONObject else {
            throw NSError(domain: "JSON", code: -1, userInfo: nil)
        }
        return obj
    }

    private static func nestedJSON(_ dict: JSONObject, keys: String...) -> JSONObject? {
        var current: Any? = dict
        for key in keys {
            guard let d = current as? JSONObject else { return nil }
            current = d[key]
        }
        return current as? JSONObject
    }

    private static func randomUserAgent() -> String {
        let osOptions = ["Windows NT 10.0; Win64; x64", "Macintosh; Intel Mac OS X 10_15_7", "X11; Linux x86_64"]
        return "Mozilla/5.0 (\(osOptions.randomElement()!)) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/\(140 - Int.random(in: 0...4)).0.\(Int.random(in: 0...499)).0 Safari/537.36"
    }

    private static func parseGqlImages(_ sources: Any?) -> [SpotifyImage] {
        guard let arr = sources as? [[String: Any]] else { return [] }
        return arr.compactMap { src in
            guard let url = src["url"] as? String else { return nil }
            return SpotifyImage(url: url, height: src["height"] as? Int, width: src["width"] as? Int)
        }
    }

    private static func parseGqlPlaylistImages(_ imagesObj: Any?) -> [SpotifyImage] {
        guard let obj = imagesObj as? JSONObject, let items = obj["items"] as? [[String: Any]] else { return [] }
        return items.flatMap { parseGqlImages($0["sources"]) }
    }

    private static func parseGqlTrack(_ trackData: JSONObject, uriOverride: String? = nil) -> SpotifyTrack? {
        let uri = uriOverride ?? (trackData["uri"] as? String) ?? ""
        let trackId = String(uri.split(separator: ":").last ?? "")
        let artistsItems = (trackData["artists"] as? JSONObject)?["items"] as? [[String: Any]] ?? []
        let artists = artistsItems.compactMap { elem -> SpotifySimpleArtist? in
            guard let u = elem["uri"] as? String else { return nil }
            return SpotifySimpleArtist(id: String(u.split(separator: ":").last ?? ""), name: (elem["profile"] as? JSONObject)?["name"] as? String ?? "", uri: u)
        }
        let albumData = trackData["albumOfTrack"] as? JSONObject
        let albumUri = albumData?["uri"] as? String ?? ""
        let album = SpotifySimpleAlbum(id: String(albumUri.split(separator: ":").last ?? ""), name: albumData?["name"] as? String ?? "", images: parseGqlImages((albumData?["coverArt"] as? JSONObject)?["sources"]), uri: albumUri.isEmpty ? nil : albumUri)
        let durationMs = (trackData["duration"] as? JSONObject)?["totalMilliseconds"] as? Int ?? trackData["durationMs"] as? Int ?? trackData["duration_ms"] as? Int ?? 0
        return SpotifyTrack(id: trackId, name: trackData["name"] as? String ?? "", artists: artists, album: album, durationMs: durationMs, uri: uri.isEmpty ? nil : uri)
    }

    private static func parsePlaylistWrapper(_ wrapper: JSONObject) -> SpotifyPlaylist? {
        guard let data = wrapper["data"] as? JSONObject, data["__typename"] as? String == "Playlist" else { return nil }
        let playlistUri = wrapper["_uri"] as? String ?? ""
        let playlistId = String(playlistUri.split(separator: ":").last ?? "")
        let ownerData = (data["ownerV2"] as? JSONObject)?["data"] as? JSONObject
        let ownerId = (ownerData?["uri"] as? String).map { String($0.split(separator: ":").last ?? "") } ?? ownerData?["id"] as? String ?? ""
        return SpotifyPlaylist(id: playlistId, name: data["name"] as? String ?? "", description: data["description"] as? String, images: parseGqlPlaylistImages(data["images"]), owner: SpotifyPlaylistOwner(id: ownerId, displayName: ownerData?["name"] as? String, uri: ownerData?["uri"] as? String), tracks: nil, uri: playlistUri, public: nil, collaborative: false, snapshotId: nil)
    }
}

// MARK: - Type alias

typealias JSONObject = [String: Any]
