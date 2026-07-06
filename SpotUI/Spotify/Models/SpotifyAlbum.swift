import Foundation

struct SpotifyAlbum: Codable {
    let id: String
    let name: String
    let albumType: String?
    let artists: [SpotifySimpleArtist]
    let images: [SpotifyImage]
    let releaseDate: String?
    let totalTracks: Int
    let tracks: SpotifyPaging<SpotifyTrack>?
    let uri: String?
    let popularity: Int?
    let genres: [String]

    enum CodingKeys: String, CodingKey {
        case id, name, artists, images, tracks, uri, popularity, genres
        case albumType = "album_type"
        case releaseDate = "release_date"
        case totalTracks = "total_tracks"
    }
}

struct SpotifySavedAlbum: Codable {
    let addedAt: String?
    let album: SpotifyAlbum

    enum CodingKeys: String, CodingKey {
        case album
        case addedAt = "added_at"
    }
}
