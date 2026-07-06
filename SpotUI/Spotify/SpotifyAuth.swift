import Foundation
import CryptoKit

/// Spotify authentication using sp_dc cookies + TOTP.
/// Port of SpotifyAuth.kt — fetches internal web-player access tokens
/// without requiring a Spotify Developer Client ID.
enum SpotifyAuth {
    private static let tokenURL = "https://open.spotify.com/api/token"
    private static let serverTimeURL = "https://open.spotify.com/api/server-time"
    private static let gistURL = "https://api.github.com/gists/22ed9c6ba463899e933427f7de1f0eef"
    private static let userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

    static let loginURL = "https://accounts.spotify.com/en/login?continue=https%3A%2F%2Fopen.spotify.com%2F&method=password&allow_password=1&allow_signup=1"
    static let signupURL = "https://www.spotify.com/signup"

    struct Nuance: Codable {
        let s: String
        let v: Int
    }

    struct GistFile: Codable {
        let content: String
    }

    struct GistFiles: Codable {
        let files: [String: GistFile]
    }

    struct ServerTimeResponse: Codable {
        let serverTime: Int64
    }

    /// Fetch an internal web-player access token using session cookies and TOTP.
    static func fetchAccessToken(spDc: String, spKey: String = "") async throws -> SpotifyInternalToken {
        let nuance = try await fetchNuance()
        let serverTimeSec = try await fetchServerTime()
        let totp = generateTotp(secret: nuance.s, serverTimeSec: serverTimeSec)

        var urlString = "\(tokenURL)?reason=transport&productType=web-player"
        urlString += "&totp=\(totp)&totpServer=\(totp)&totpVer=\(nuance.v)"

        var cookieHeader = "sp_dc=\(spDc)"
        if !spKey.isEmpty {
            cookieHeader += "; sp_key=\(spKey)"
        }

        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("en", forHTTPHeaderField: "Accept-Language")
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw SpotifyAPIError.httpError((response as? HTTPURLResponse)?.statusCode ?? -1, body)
        }

        let token = try JSONDecoder().decode(SpotifyInternalToken.self, from: data)
        if token.isAnonymous || token.accessToken.isEmpty {
            throw SpotifyAPIError.httpError(401, "Received anonymous token — sp_dc cookie is invalid or expired")
        }
        return token
    }

    // MARK: - Private helpers

    private static func fetchNuance() async throws -> Nuance {
        guard let url = URL(string: gistURL) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        let gist = try JSONDecoder().decode(GistFiles.self, from: data)
        guard let content = gist.files.values.first?.content else {
            throw SpotifyAPIError.httpError(500, "Gist has no files")
        }
        let nuances = try JSONDecoder().decode([Nuance].self, from: content.data(using: .utf8)!)
        guard let best = nuances.max(by: { $0.v < $1.v }) else {
            throw SpotifyAPIError.httpError(500, "No nuance data found")
        }
        return best
    }

    private static func fetchServerTime() async throws -> Int64 {
        guard let url = URL(string: serverTimeURL) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(ServerTimeResponse.self, from: data)
        return response.serverTime
    }

    /// Generate a 6-digit TOTP using HMAC-SHA1 (RFC 6238).
    private static func generateTotp(secret: String, serverTimeSec: Int64) -> String {
        let key = base32Decode(secret)
        let interval: Int64 = 30
        let timeStep = serverTimeSec / interval

        var timeBytes = [UInt8](repeating: 0, count: 8)
        var value = UInt64(bitPattern: timeStep)
        for i in (0..<8).reversed() {
            timeBytes[i] = UInt8(value & 0xFF)
            value >>= 8
        }

        let SymmetricKey = SymmetricKey(data: Data(key))
        let signature = HMAC<Insecure.SHA1>.authenticationCode(for: Data(timeBytes), using: SymmetricKey)
        let hash = Data(signature)

        let offset = Int(hash[hash.endIndex - 1]) & 0x0F
        let code = ((Int(hash[offset]) & 0x7F) << 24) |
                   ((Int(hash[offset + 1]) & 0xFF) << 16) |
                   ((Int(hash[offset + 2]) & 0xFF) << 8) |
                   (Int(hash[offset + 3]) & 0xFF)

        let otp = code % 1_000_000
        return String(format: "%06d", otp)
    }

    private static func base32Decode(_ input: String) -> [UInt8] {
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        let cleaned = input.uppercased().filter { $0 != "=" }
        var output = [UInt8]()
        var buffer = 0
        var bitsLeft = 0

        for c in cleaned {
            guard let value = alphabet.firstIndex(of: c)?.encodedOffset else { continue }
            buffer = (buffer << 5) | value
            bitsLeft += 5
            if bitsLeft >= 8 {
                bitsLeft -= 8
                output.append(UInt8((buffer >> bitsLeft) & 0xFF))
            }
        }
        return output
    }
}
