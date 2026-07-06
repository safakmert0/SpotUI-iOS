import Foundation

struct SearchResults: Codable {
    let songs: [Track]
    let albums: [Album]
    let artists: [Artist]
    let shows: [Podcast]
    let episodes: [Track]

    init(
        songs: [Track] = [],
        albums: [Album] = [],
        artists: [Artist] = [],
        shows: [Podcast] = [],
        episodes: [Track] = []
    ) {
        self.songs = songs
        self.albums = albums
        self.artists = artists
        self.shows = shows
        self.episodes = episodes
    }
}
