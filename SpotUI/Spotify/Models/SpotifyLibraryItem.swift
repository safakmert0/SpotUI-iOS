import Foundation

enum SpotifyLibraryItem: Codable {
    case playlist(SpotifyPlaylist)
    case folder(SpotifyLibraryFolder)

    var uri: String {
        switch self {
        case .playlist(let p): return p.uri ?? "spotify:playlist:\(p.id)"
        case .folder(let f): return f.uri
        }
    }
}

struct SpotifyLibraryFolder: Codable {
    let uri: String
    let name: String
    let totalChildren: Int
}
