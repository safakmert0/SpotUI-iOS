import Foundation

/// SongsModel equivalent — a single track for playback and display.
struct Track: Identifiable, Hashable, Codable {
    let id: Int
    let title: String
    let album: String
    let singer: String
    let coverUri: String
    let url: String
    let spotifyTrackId: String
    let explicit: Bool
    let durationMs: Int

    init(
        id: Int = -1,
        title: String = "",
        album: String = "",
        singer: String = "",
        coverUri: String = "",
        url: String = "",
        spotifyTrackId: String = "",
        explicit: Bool = false,
        durationMs: Int = 0
    ) {
        self.id = id
        self.title = title
        self.album = album
        self.singer = singer
        self.coverUri = coverUri
        self.url = url
        self.spotifyTrackId = spotifyTrackId
        self.explicit = explicit
        self.durationMs = durationMs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.id == rhs.id
    }
}
