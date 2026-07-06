import Foundation

struct SpotifyArtist: Codable {
    let id: String
    let name: String
    let images: [SpotifyImage]
    let genres: [String]
    let popularity: Int?
    let uri: String?
}
