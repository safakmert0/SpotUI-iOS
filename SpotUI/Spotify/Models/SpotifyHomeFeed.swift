import Foundation

struct SpotifyHomeFeed: Codable {
    let greeting: String?
    let sections: [SpotifyHomeFeedSection]
}

struct SpotifyHomeFeedSection: Codable {
    let sectionUri: String
    let title: String?
    let typename: String
    let totalCount: Int
    let items: [SpotifyHomeFeedItem]
}

enum SpotifyHomeFeedItem: Codable {
    case playlist(SpotifyHomeFeedPlaylist)
    case album(SpotifyHomeFeedAlbum)
    case artist(SpotifyHomeFeedArtist)

    var uri: String {
        switch self {
        case .playlist(let p): return p.uri
        case .album(let a): return a.uri
        case .artist(let a): return a.uri
        }
    }
}

struct SpotifyHomeFeedPlaylist: Codable {
    let uri: String
    let id: String
    let name: String
    let description: String?
    let format: String?
    let totalCount: Int
    let imageUrl: String?
    let extractedColorHex: String?
    let ownerName: String?
    let madeForUsername: String?
}

struct SpotifyHomeFeedAlbum: Codable {
    let uri: String
    let id: String
    let name: String
    let albumType: String?
    let artists: [SpotifySimpleArtist]
    let imageUrl: String?
}

struct SpotifyHomeFeedArtist: Codable {
    let uri: String
    let id: String
    let name: String
    let imageUrl: String?
}
