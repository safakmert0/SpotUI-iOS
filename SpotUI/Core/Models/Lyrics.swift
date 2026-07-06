import Foundation

struct LyricLine: Identifiable, Codable {
    let timeMs: Int64
    let text: String

    var id: Int64 { timeMs }
}

struct Lyrics: Codable {
    let lines: [LyricLine]
    let synced: Bool

    var isEmpty: Bool { lines.isEmpty }
}
