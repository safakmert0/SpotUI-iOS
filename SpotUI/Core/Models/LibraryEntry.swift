import Foundation

struct LibraryEntry: Identifiable, Hashable, Codable {
    let spotifyId: String
    let name: String
    let subtitle: String
    let coverUri: String
    let isPlaylist: Bool
    let artists: String

    var id: String { spotifyId }
}
