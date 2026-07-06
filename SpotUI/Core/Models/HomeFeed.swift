import Foundation

struct HomeFeedModel: Codable {
    let greeting: String
    let sections: [HomeSection]

    init(greeting: String = "", sections: [HomeSection] = []) {
        self.greeting = greeting
        self.sections = sections
    }
}

struct HomeSection: Codable, Identifiable {
    let title: String
    let items: [HomeItem]

    var id: String { title }
}

enum HomeItem: Codable, Identifiable {
    case album(HomeAlbum)
    case artist(HomeArtist)
    case playlist(HomePlaylist)

    var id: String {
        switch self {
        case .album(let a): return "album-\(a.name)"
        case .artist(let a): return "artist-\(a.name)"
        case .playlist(let p): return "playlist-\(p.name)"
        }
    }

    var name: String {
        switch self {
        case .album(let a): return a.name
        case .artist(let a): return a.name
        case .playlist(let p): return p.name
        }
    }

    var imageUrl: String {
        switch self {
        case .album(let a): return a.imageUrl
        case .artist(let a): return a.imageUrl
        case .playlist(let p): return p.imageUrl
        }
    }
}

struct HomeAlbum: Codable {
    let name: String
    let imageUrl: String
    let subtitle: String
    let artists: String
}

struct HomeArtist: Codable {
    let name: String
    let imageUrl: String
    let id: String
}

struct HomePlaylist: Codable {
    let name: String
    let imageUrl: String
    let subtitle: String
    let id: String
}
