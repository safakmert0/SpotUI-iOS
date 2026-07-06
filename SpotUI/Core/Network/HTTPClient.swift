import Foundation

/// Shared HTTP client wrapping URLSession with cookie management and retry logic.
final class HTTPClient {
    static let shared = HTTPClient()

    private let session: URLSession
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder

    private init() {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpCookieAcceptPolicy = .always
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)

        self.jsonDecoder = JSONDecoder()
        self.jsonEncoder = JSONEncoder()
    }

    // MARK: - GET

    func get<T: Decodable>(
        _ urlString: String,
        headers: [String: String] = [:],
        decoder: JSONDecoder? = nil
    ) async throws -> T {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw SpotifyAPIError.httpError(code, String(data: data, encoding: .utf8) ?? "")
        }
        return try (decoder ?? jsonDecoder).decode(T.self, from: data)
    }

    // MARK: - POST JSON

    func post<T: Decodable>(
        _ urlString: String,
        body: Data,
        headers: [String: String] = [:],
        decoder: JSONDecoder? = nil
    ) async throws -> T {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw SpotifyAPIError.httpError(code, String(data: data, encoding: .utf8) ?? "")
        }
        return try (decoder ?? jsonDecoder).decode(T.self, from: data)
    }

    // MARK: - POST raw bytes (for protobuf, etc.)

    func postRaw(
        _ urlString: String,
        body: Data,
        contentType: String,
        headers: [String: String] = [:]
    ) async throws -> (Data, HTTPURLResponse) {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw SpotifyAPIError.httpError(code, String(data: data, encoding: .utf8) ?? "")
        }
        return (data, http)
    }

    // MARK: - GET raw Data (for non-JSON responses)

    func getData(
        _ urlString: String,
        headers: [String: String] = [:]
    ) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw SpotifyAPIError.httpError(code, String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }

    // MARK: - Download with progress

    func download(
        _ urlString: String,
        headers: [String: String] = [:],
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> URL {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let (tempURL, response) = try await session.download(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SpotifyAPIError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1, "Download failed")
        }
        return tempURL
    }
}

enum SpotifyAPIError: Error, LocalizedError {
    case httpError(Int, String)
    case decodingError(Error)
    case notAuthenticated
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .httpError(let code, let body): return "HTTP \(code): \(body.prefix(200))"
        case .decodingError(let e): return "Decoding error: \(e.localizedDescription)"
        case .notAuthenticated: return "Not authenticated — set sp_dc cookie"
        case .rateLimited: return "Rate limited — try again later"
        }
    }
}
