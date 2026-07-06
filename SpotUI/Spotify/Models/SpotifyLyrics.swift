import Foundation

struct SpotifyLyrics: Codable {
    let synced: Bool
    let lines: [SpotifyLyricLine]
}

struct SpotifyLyricLine: Codable {
    let startMs: Int64
    let words: String
}
