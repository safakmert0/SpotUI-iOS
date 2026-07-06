import Foundation

struct SpotifyPlaylist: Codable {
    let id: String
    let name: String
    let description: String?
    let images: [SpotifyImage]
    let owner: SpotifyPlaylistOwner?
    let tracks: SpotifyPlaylistTracksRef?
    let uri: String?
    let `public`: Bool?
    let collaborative: Bool
    let snapshotId: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description, images, owner, tracks, uri, collaborative
        case `public`
        case snapshotId = "snapshot_id"
    }
}

struct SpotifyPlaylistOwner: Codable {
    let id: String
    let displayName: String?
    let uri: String?

    enum CodingKeys: String, CodingKey {
        case id, uri
        case displayName = "display_name"
    }
}

struct SpotifyPlaylistTracksRef: Codable {
    let total: Int
    let href: String?
}

struct SpotifyPlaylistTrack: Codable {
    let addedAt: String?
    let track: SpotifyTrack?
    let isLocal: Bool
    let uid: String?

    enum CodingKeys: String, CodingKey {
        case track, uid
        case addedAt = "added_at"
        case isLocal = "is_local"
    }
}
