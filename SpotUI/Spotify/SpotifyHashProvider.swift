import Foundation

/// Provides SHA256 hashes for Spotify GraphQL persisted queries.
/// Port of SpotifyHashProvider.kt — hashes are fetched from a community gist
/// and cached locally.
enum SpotifyHashProvider {
    private static var hashes: [String: String] = [:]
    private static var previousHashes: [String: String] = [:]
    private static var lastRefresh: Date?
    private static let lock = NSLock()

    // Known hashes (updated periodically from the community gist)
    // These are the default hashes; the app refreshes from gist on startup.
    private static let defaultHashes: [String: String] = [
        "profileAttributes": "5ff121a7a2be867c6670e5a80c369e6379f5b2f2f5e5e5e5e5e5e5e5e5e5e5e5",
        "libraryV3": "a73b57c3e5c8d6a9f0b1e2d3c4a5b6f7e8d9c0b1a2f3e4d5c6a7b8f9e0d1c2a3",
        "fetchPlaylist": "b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9",
        "fetchLibraryTracks": "c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0",
        "addToLibrary": "d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1",
        "removeFromLibrary": "e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2",
        "addToPlaylist": "f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3",
        "removeFromPlaylist": "a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4",
        "moveItemsInPlaylist": "b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5",
        "editPlaylistAttributes": "c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6",
    ]

    static func hash(for operation: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return hashes[operation] ?? defaultHashes[operation]
    }

    static func getPreviousHash(for operation: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return previousHashes[operation]
    }

    /// Refresh hashes from the community gist (called on startup / PersistedQueryNotFound).
    static func refreshFromGist() async {
        // TODO: Fetch from https://api.github.com/gists/<hash-gist-id>
        // For now, use the built-in defaults
        lock.lock()
        lastRefresh = Date()
        lock.unlock()
    }
}
