import Foundation

struct SpotifySearchResult: Codable {
    let tracks: SpotifyPaging<SpotifyTrack>?
    let playlists: SpotifyPaging<SpotifyPlaylist>?
    let albums: SpotifyPaging<SpotifyAlbum>?
    let artists: SpotifyPaging<SpotifyArtist>?
}
