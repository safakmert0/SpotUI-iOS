import Foundation

struct SpotifyShow: Codable {
    let id: String
    let name: String
    let publisher: String
    let description: String
    let images: [SpotifyImage]
    let totalEpisodes: Int
    let uri: String?

    enum CodingKeys: String, CodingKey {
        case id, name, publisher, description, images, uri
        case totalEpisodes = "total_episodes"
    }
}

struct SpotifyEpisode: Codable {
    let id: String
    let name: String
    let description: String
    let images: [SpotifyImage]
    let durationMs: Int
    let releaseDate: String
    let uri: String?
    let show: SpotifyShow?

    enum CodingKeys: String, CodingKey {
        case id, name, description, images, uri, show
        case durationMs = "duration_ms"
        case releaseDate = "release_date"
    }
}

struct SpotifyPodcastSearchResult: Codable {
    let shows: SpotifyPaging<SpotifyShow>?
    let episodes: SpotifyPaging<SpotifyEpisode>?
}
