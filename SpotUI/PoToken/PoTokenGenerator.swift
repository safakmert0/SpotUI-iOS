import Foundation

/// Manages PoToken generation with caching and session management.
/// Port of PoTokenGenerator.kt.
@MainActor
final class PoTokenGenerator {
    static let shared = PoTokenGenerator()

    private var webPoTokenGenerator: PoTokenWebView?
    private var webPoTokenSessionId: String?
    private var webPoTokenStreamingPot: String?

    func getWebClientPoToken(videoId: String, sessionId: String) async -> PoTokenResult? {
        do {
            return try await getWebClientPoTokenInternal(videoId: videoId, sessionId: sessionId, forceRecreate: false)
        } catch {
            do {
                return try await getWebClientPoTokenInternal(videoId: videoId, sessionId: sessionId, forceRecreate: true)
            } catch {
                return nil
            }
        }
    }

    private func getWebClientPoTokenInternal(videoId: String, sessionId: String, forceRecreate: Bool) async throws -> PoTokenResult {
        let shouldRecreate = forceRecreate || webPoTokenGenerator == nil || webPoTokenGenerator!.isExpired || webPoTokenSessionId != sessionId

        if shouldRecreate {
            webPoTokenSessionId = sessionId
            webPoTokenGenerator?.close()
            webPoTokenGenerator = try await PoTokenWebView.getNewPoTokenGenerator()
            webPoTokenStreamingPot = try await webPoTokenGenerator!.generatePoToken(sessionId)
        }

        let playerPot = try await webPoTokenGenerator!.generatePoToken(videoId)
        guard let streamingPot = webPoTokenStreamingPot else {
            throw PoTokenError.initializationFailed("No streaming pot")
        }
        return PoTokenResult(playerPot: playerPot, streamingPot: streamingPot)
    }
}
