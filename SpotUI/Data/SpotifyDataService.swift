import Foundation
import Combine

/// Spotify-backed data service. Port of Api.kt.
/// Coordinates Spotify API calls and maps results to app models.
@MainActor
final class SpotifyDataService: ObservableObject {
    static let shared = SpotifyDataService()

    @Published var homeFeed: HomeFeedModel?
    @Published var library: [LibraryEntry]?
    @Published var account: Account?

    // Cache
    private var cachedAlbums: [Album]?
    private var cachedArtists: [Artist]?

    func ensureAuthenticated() async -> Bool {
        return await SpotifyTokenProvider.shared.ensureToken()
    }

    // MARK: - Home Feed

    func home() async -> HomeFeedModel {
        if let cached = homeFeed { return cached }
        guard await ensureAuthenticated() else { return HomeFeedModel() }
        // TODO: Port the full GQL home feed parsing from Api.kt
        // For now, return empty
        return HomeFeedModel()
    }

    // MARK: - Library

    func library() async -> [LibraryEntry] {
        if let cached = library { return cached }
        guard await ensureAuthenticated() else { return [] }
        do {
            let playlists = try await SpotifyAPI.myPlaylists()
            let entries = playlists.items.map { playlist in
                LibraryEntry(
                    spotifyId: playlist.id,
                    name: playlist.name,
                    subtitle: playlist.owner?.displayName ?? "",
                    coverUri: SpotifyMapper.playlistThumbnail(playlist) ?? "",
                    isPlaylist: true,
                    artists: ""
                )
            }
            library = entries
            return entries
        } catch {
            print("SpotifyDataService: library failed — \(error)")
            return []
        }
    }

    // MARK: - Playlist songs

    func playlistSongs(playlistId: String) async -> [Track] {
        guard await ensureAuthenticated() else { return [] }
        do {
            let tracks = try await SpotifyAPI.playlistTracks(playlistId: playlistId)
            return tracks.items.compactMap { $0.track }.map(SpotifyMapper.toTrack)
        } catch {
            print("SpotifyDataService: playlistSongs failed — \(error)")
            return []
        }
    }

    // MARK: - Album songs

    func albumSongs(name: String, artist: String) async -> [Track] {
        guard await ensureAuthenticated() else { return [] }
        // TODO: Search for album by name+artist, then fetch tracks
        return []
    }

    // MARK: - Liked songs

    func likedSongs() async -> [Track] {
        guard await ensureAuthenticated() else { return [] }
        do {
            let saved = try await SpotifyAPI.likedSongs()
            return saved.items.map(SpotifyMapper.toTrack)
        } catch {
            print("SpotifyDataService: likedSongs failed — \(error)")
            return []
        }
    }

    // MARK: - Search

    func search(query: String) async -> SearchResults {
        guard await ensureAuthenticated() else { return SearchResults() }
        do {
            let result = try await SpotifyAPI.search(query: query)
            let songs = result.tracks?.items.map(SpotifyMapper.toTrack) ?? []
            let albums = result.albums?.items.map(SpotifyMapper.toAlbum) ?? []
            let artists = result.artists?.items.map(SpotifyMapper.toArtist) ?? []
            return SearchResults(songs: songs, albums: albums, artists: artists)
        } catch {
            print("SpotifyDataService: search failed — \(error)")
            return SearchResults()
        }
    }

    // MARK: - Artist

    func artistOverview(artistId: String) async -> ArtistOverview {
        guard await ensureAuthenticated() else { return ArtistOverview() }
        do {
            let artist = try await SpotifyAPI.artist(artistId)
            let topTracks = try await SpotifyAPI.artistTopTracks(artistId: artistId)
            let albums = try await SpotifyAPI.artistAlbums(artistId: artistId)
            return ArtistOverview(
                id: artist.id,
                name: artist.name,
                avatarImage: artist.images.first?.url ?? "",
                topTracks: topTracks.map { ArtistTrackUI(song: SpotifyMapper.toTrack($0), playcount: nil) },
                popularReleases: albums.items.map(SpotifyMapper.toAlbum)
            )
        } catch {
            print("SpotifyDataService: artistOverview failed — \(error)")
            return ArtistOverview()
        }
    }

    // MARK: - Lyrics

    func lyrics(trackId: String) async -> Lyrics? {
        guard await ensureAuthenticated() else { return nil }
        do {
            let result = try await SpotifyAPI.lyrics(trackId: trackId)
            return Lyrics(
                lines: result.lines.map { LyricLine(timeMs: $0.startMs, text: $0.words) },
                synced: result.synced
            )
        } catch {
            return nil
        }
    }

    // MARK: - Recommendations

    func recommendations(seedTrackIds: [String]) async -> [Track] {
        guard await ensureAuthenticated() else { return [] }
        do {
            let result = try await SpotifyAPI.recommendations(seedTracks: seedTrackIds)
            return result.tracks.map(SpotifyMapper.toTrack)
        } catch {
            return []
        }
    }

    // MARK: - Account

    func accountInfo() async -> Account {
        if let cached = account { return cached }
        guard await ensureAuthenticated() else { return Account() }
        do {
            let user = try await SpotifyAPI.me()
            let acct = Account(
                name: user.displayName ?? "",
                email: user.email ?? "",
                imageUrl: user.images.first?.url ?? "",
                plan: user.product ?? ""
            )
            account = acct
            return acct
        } catch {
            return Account()
        }
    }

    // MARK: - Library mutations

    func likeTrack(_ track: Track) async {
        guard await ensureAuthenticated() else { return }
        try? await SpotifyAPI.addToLibrary(uris: ["spotify:track:\(track.spotifyTrackId)"])
    }

    func unlikeTrack(_ track: Track) async {
        guard await ensureAuthenticated() else { return }
        try? await SpotifyAPI.removeFromLibrary(uris: ["spotify:track:\(track.spotifyTrackId)"])
    }

    func clearCache() {
        homeFeed = nil
        library = nil
        account = nil
        cachedAlbums = nil
        cachedArtists = nil
    }
}
