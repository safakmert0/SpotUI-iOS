import Foundation

struct SpotifyTrack: Codable {
    let id: String
    let name: String
    let artists: [SpotifySimpleArtist]
    let album: SpotifySimpleAlbum?
    let durationMs: Int
    let explicit: Bool
    let isLocal: Bool
    let previewUrl: String?
    let trackNumber: Int?
    let uri: String?
    let popularity: Int?
    let externalIds: SpotifyExternalIds?

    var isrc: String? { externalIds?.isrc }

    enum CodingKeys: String, CodingKey {
        case id, name, artists, album, explicit, uri, popularity
        case durationMs = "duration_ms"
        case isLocal = "is_local"
        case previewUrl = "preview_url"
        case trackNumber = "track_number"
        case externalIds = "external_ids"
    }

    init(
        id: String = "",
        name: String = "",
        artists: [SpotifySimpleArtist] = [],
        album: SpotifySimpleAlbum? = nil,
        durationMs: Int = 0,
        explicit: Bool = false,
        isLocal: Bool = false,
        previewUrl: String? = nil,
        trackNumber: Int? = nil,
        uri: String? = nil,
        popularity: Int? = nil,
        externalIds: SpotifyExternalIds? = nil
    ) {
        self.id = id
        self.name = name
        self.artists = artists
        self.album = album
        self.durationMs = durationMs
        self.explicit = explicit
        self.isLocal = isLocal
        self.previewUrl = previewUrl
        self.trackNumber = trackNumber
        self.uri = uri
        self.popularity = popularity
        self.externalIds = externalIds
    }
}

struct SpotifyExternalIds: Codable {
    let isrc: String?
    let ean: String?
    let upc: String?
}

struct SpotifySimpleArtist: Codable {
    let id: String?
    let name: String
    let uri: String?

    init(id: String? = nil, name: String = "", uri: String? = nil) {
        self.id = id
        self.name = name
        self.uri = uri
    }
}

struct SpotifySimpleAlbum: Codable {
    let id: String
    let name: String
    let images: [SpotifyImage]
    let releaseDate: String?
    let albumType: String?
    let artists: [SpotifySimpleArtist]
    let uri: String?

    enum CodingKeys: String, CodingKey {
        case id, name, images, artists, uri
        case releaseDate = "release_date"
        case albumType = "album_type"
    }

    init(
        id: String = "",
        name: String = "",
        images: [SpotifyImage] = [],
        releaseDate: String? = nil,
        albumType: String? = nil,
        artists: [SpotifySimpleArtist] = [],
        uri: String? = nil
    ) {
        self.id = id
        self.name = name
        self.images = images
        self.releaseDate = releaseDate
        self.albumType = albumType
        self.artists = artists
        self.uri = uri
    }
}

struct SpotifySavedTrack: Codable {
    let addedAt: String?
    let track: SpotifyTrack

    enum CodingKeys: String, CodingKey {
        case track
        case addedAt = "added_at"
    }
}
