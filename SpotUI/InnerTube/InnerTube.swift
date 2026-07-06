import Foundation

/// YouTube InnerTube HTTP client.
/// Port of InnerTube.kt — sends requests to YouTube Music's internal API.
final class InnerTube {
    static let shared = InnerTube()

    private let baseURL = "https://music.youtube.com/youtubei/v1"

    var visitorData: String?
    var dataSyncId: String?
    var locale = YouTubeLocale()

    struct YouTubeLocale {
        var language: String = "en"
        var country: String = "US"
    }

    struct ClientConfig {
        let clientName: String
        let clientVersion: String
        let apiKey: String
        let androidSdkVersion: Int?

        static let webRemix = ClientConfig(
            clientName: "WEB_REMIX",
            clientVersion: "1.20240620.01.00",
            apiKey: "AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30",
            androidSdkVersion: nil
        )
    }

    /// Search YouTube Music.
    func search(
        query: String,
        filter: String = "songs",
        client: ClientConfig = .webRemix
    ) async throws -> SearchResponse {
        let body = buildRequestBody(client: client, query: query, filter: filter)
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        let urlString = "\(baseURL)/search?key=\(client.apiKey)"
        let data = try await HTTPClient.shared.post(urlString, body: bodyData, headers: [
            "Content-Type": "application/json",
            "X-Goog-Visitor-Id": visitorData ?? "",
        ])
        return try JSONDecoder().decode(SearchResponse.self, from: data)
    }

    /// Get player info for a video.
    func player(
        videoId: String,
        client: ClientConfig = .webRemix
    ) async throws -> PlayerResponse {
        let body = buildPlayerBody(client: client, videoId: videoId)
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        let urlString = "\(baseURL)/player?key=\(client.apiKey)"
        let data = try await HTTPClient.shared.post(urlString, body: bodyData, headers: [
            "Content-Type": "application/json",
            "X-Goog-Visitor-Id": visitorData ?? "",
        ])
        return try JSONDecoder().decode(PlayerResponse.self, from: data)
    }

    // MARK: - Private

    private func buildRequestBody(client: ClientConfig, query: String, filter: String) -> JSONObject {
        var context: JSONObject = [
            "client": [
                "clientName": client.clientName,
                "clientVersion": client.clientVersion,
                "hl": locale.language,
                "gl": locale.country,
            ]
        ]
        if let sdk = client.androidSdkVersion {
            context["client"]?["androidSdkVersion"] = sdk
        }
        if let visitor = visitorData {
            context["client"]?["visitorData"] = visitor
        }
        return [
            "context": context,
            "query": query,
            "params": filterParam(for: filter),
        ]
    }

    private func buildPlayerBody(client: ClientConfig, videoId: String) -> JSONObject {
        var context: JSONObject = [
            "client": [
                "clientName": client.clientName,
                "clientVersion": client.clientVersion,
                "hl": locale.language,
                "gl": locale.country,
            ]
        ]
        if let sdk = client.androidSdkVersion {
            context["client"]?["androidSdkVersion"] = sdk
        }
        if let visitor = visitorData {
            context["client"]?["visitorData"] = visitor
        }
        return [
            "context": context,
            "videoId": videoId,
        ]
    }

    private func filterParam(for filter: String) -> String {
        switch filter {
        case "songs": return "EgWKAQIIAWoKEAMQBRAJEAoQAQ=="
        case "videos": return "EgWKAQDYAQ=="
        case "albums": return "EgWKAQIaAQ=="
        case "artists": return "EgWKAQFYAQ=="
        case "playlists": return "EgWKAQFoAQ=="
        default: return ""
        }
    }
}

// MARK: - HTTP method on HTTPClient for InnerTube

extension HTTPClient {
    func post(_ urlString: String, body: Data, headers: [String: String] = [:]) async throws -> Data {
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw SpotifyAPIError.httpError(code, String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }
}
