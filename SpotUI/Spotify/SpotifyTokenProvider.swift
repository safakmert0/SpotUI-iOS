import Foundation

/// Manages Spotify access tokens — caches and refreshes.
/// Port of SpotifyTokenProvider.kt.
final class SpotifyTokenProvider {
    static let shared = SpotifyTokenProvider()

    private var cachedToken: SpotifyInternalToken?
    private var tokenExpiry: Date?
    private let lock = NSLock()

    /// Current valid access token, or nil if expired / not fetched.
    var accessToken: String? {
        lock.lock()
        defer { lock.unlock() }
        if let token = cachedToken, let expiry = tokenExpiry, Date() < expiry {
            return token.accessToken
        }
        return nil
    }

    /// Ensure we have a valid token. Returns true on success.
    @discardableResult
    func ensureToken() async -> Bool {
        if accessToken != nil { return true }
        return await refreshToken()
    }

    @discardableResult
    func refreshToken() async -> Bool {
        let spDc = SpotifySession.shared.spDc
        guard !spDc.isEmpty else { return false }

        do {
            let token = try await SpotifyAuth.fetchAccessToken(spDc: spDc)
            lock.lock()
            cachedToken = token
            // Expire 5 minutes early for safety
            tokenExpiry = Date(timeIntervalSince1970: Double(token.accessTokenExpirationTimestampMs) / 1000.0 - 300)
            lock.unlock()

            // Update global Spotify API token
            SpotifyAPI.accessToken = token.accessToken
            return true
        } catch {
            print("SpotifyTokenProvider: refresh failed — \(error.localizedDescription)")
            return false
        }
    }
}
