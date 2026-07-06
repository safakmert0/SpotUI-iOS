import Foundation

/// Navigation routes — port of Routes.kt.
enum Route: Hashable {
    case home
    case search
    case library
    case player
    case playlist(id: String, name: String)
    case album(name: String, artist: String)
    case artist(name: String, id: String)
    case queue
    case liked
    case downloads
    case history
    case settings
    case login
    case category(genre: String, title: String)
    case show(id: String, name: String)
}
