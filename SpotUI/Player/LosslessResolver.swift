import Foundation
import CryptoKit

/// Lossless (FLAC) resolver. Port of SpotiFlac.kt.
/// Resolves Spotify tracks to lossless FLAC URLs via community proxy servers.
enum LosslessResolver {

    struct LosslessTrack {
        let url: String
        let provider: String
        let quality: String
    }

    private static let apiKey = "explore-obscure-chivalry-travesty-blinks"
    private static let tidalBase = "https://tdl-foss.spotbye.qzz.io"
    private static let qobuzBase = "https://qbz-foss.spotbye.qzz.io"
    private static let amazonBase = "https://amz-foss.spotbye.qzz.io"
    private static let dlPath = "/api/dl"
    private static let userAgent = "SpotiFLAC"

    // Qobuz
    private static let qobuzAppId = "712109809"
    private static let qobuzAppSecret = "589be88e4538daea11f509d29e4a23b1"
    private static let qobuzApiBase = "https://www.qobuz.com/api.json/0.2"

    private static let client = HTTPClient.shared

    /// Resolve a lossless FLAC URL for a Spotify track.
    static func resolve(
        spotifyTrackId: String,
        isrc: String? = nil,
        preferHiRes: Bool = true
    ) async throws -> LosslessTrack {
        let quality = preferHiRes ? "24" : "16"
        let ids = try await resolveProviderIds(spotifyTrackId: spotifyTrackId, isrc: isrc)

        let attempts: [(provider: String, base: String, id: String?)] = [
            ("tidal", tidalBase, ids.tidalId),
            ("qobuz", qobuzBase, ids.qobuzId),
            ("amazon", amazonBase, ids.amazonId),
        ]

        for attempt in attempts {
            guard let id = attempt.id, !id.isEmpty else { continue }
            if let result = try? await communityDownload(provider: attempt.provider, base: attempt.base, id: id, quality: quality) {
                return result
            }
        }

        throw LosslessError.notFound
    }

    // MARK: - Private

    private struct ProviderIds {
        var tidalId: String?
        var amazonId: String?
        var qobuzId: String?
    }

    private static func resolveProviderIds(spotifyTrackId: String, isrc: String?) async throws -> ProviderIds {
        // Odesli: spotify track → all-platform links
        var tidalId: String?
        var amazonId: String?

        let odesliURL = "https://api.song.link/v1-alpha.1/links?url=spotify:track:\(spotifyTrackId)"
        if let data = try? await client.getData(odesliURL, headers: ["User-Agent": "Mozilla/5.0"]),
           let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let platforms = raw["linksByPlatform"] as? [String: Any] {
            tidalId = entityId(from: platforms, platform: "tidal")
            amazonId = entityId(from: platforms, platform: "amazonMusic")
        }

        // Qobuz: ISRC search
        var qobuzId: String?
        if let isrc, !isrc.isEmpty {
            qobuzId = await qobuzIdForIsrc(isrc)
        }

        return ProviderIds(tidalId: tidalId, amazonId: amazonId, qobuzId: qobuzId)
    }

    private static func entityId(from platforms: [String: Any], platform: String) -> String? {
        guard let platformData = platforms[platform] as? [String: Any],
              let uniqueId = platformData["entityUniqueId"] as? String else { return nil }
        guard let id = uniqueId.components(separatedBy: "::").last, !id.isEmpty, id != uniqueId else { return nil }
        return id
    }

    private static func qobuzIdForIsrc(_ isrc: String) async -> String? {
        let ts = String(Int(Date().timeIntervalSince1970))
        let params = ["query": isrc.trimmingCharacters(in: .whitespaces), "limit": "1"]
        let sigPayload = "tracksearch" + params.sorted(by: { $0.key < $1.key }).map { $0.key + $0.value }.joined() + ts + qobuzAppSecret
        let sig = md5Hex(sigPayload)

        var urlComponents = URLComponents(string: "\(qobuzApiBase)/track/search")!
        urlComponents.queryItems = [
            URLQueryItem(name: "query", value: isrc),
            URLQueryItem(name: "limit", value: "1"),
            URLQueryItem(name: "app_id", value: qobuzAppId),
            URLQueryItem(name: "request_ts", value: ts),
            URLQueryItem(name: "request_sig", value: sig),
        ]

        guard let data = try? await client.getData(urlComponents.url!.absoluteString, headers: [
            "User-Agent": "Mozilla/5.0",
            "X-App-Id": qobuzAppId,
            "Accept": "application/json",
        ]),
        let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let tracks = raw["tracks"] as? [String: Any],
        let items = tracks["items"] as? [[String: Any]],
        let first = items.first,
        let id = first["id"] as? Int else {
            return nil
        }
        return String(id)
    }

    private static func communityDownload(provider: String, base: String, id: String, quality: String) async throws -> LosslessTrack {
        let urlString = "\(base)\(dlPath)"
        let body: [String: Any] = ["id": id, "quality": quality]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try try await client.postRaw(
            urlString,
            body: bodyData,
            contentType: "application/json",
            headers: [
                "x-api-key": apiKey,
                "User-Agent": userAgent,
                "Accept": "application/json",
            ]
        )

        guard let streamUrl = extractStreamUrl(from: data) else {
            throw LosslessError.notFound
        }
        let q = quality == "24" ? "24-bit" : "16-bit"
        return LosslessTrack(url: streamUrl, provider: provider, quality: q)
    }

    private static func extractStreamUrl(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let url = json["url"] as? String, url.hasPrefix("http") { return url }
        if let url = json["download_url"] as? String, url.hasPrefix("http") { return url }
        if let dataObj = json["data"] as? [String: Any] {
            if let url = dataObj["url"] as? String, url.hasPrefix("http") { return url }
            if let url = dataObj["download_url"] as? String, url.hasPrefix("http") { return url }
        }
        return nil
    }

    private static func md5Hex(_ s: String) -> String {
        let digest = Insecure.MD5.hash(data: s.data(using: .utf8)!)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    enum LosslessError: Error, LocalizedError {
        case notFound
        case cooldown(String)

        var errorDescription: String? {
            switch self {
            case .notFound: return "No lossless match found"
            case .cooldown(let msg): return msg
            }
        }
    }
}
