import Foundation

/// Maps Spotify API models to app models.
/// Port of SpotifyMapper.kt + the toSongModel() extension in Api.kt.
enum SpotifyMapper {

    private static let featPattern = try! NSRegularExpression(pattern: "\\(feat\\..*?\\)")
    private static let ftPattern = try! NSRegularExpression(pattern: "\\(ft\\..*?\\)")
    private static let bracketPattern = try! NSRegularExpression(pattern: "\\[.*?]")
    private static let remasterPattern = try! NSRegularExpression(pattern: "\\(.*?remaster.*?\\)", options: .caseInsensitive)
    private static let nonAlnumPattern = try! NSRegularExpression(pattern: "[^a-z0-9\\s]")
    private static let multiSpacePattern = try! NSRegularExpression(pattern: "\\s+")

    // MARK: - Spotify → App models

    static func toTrack(_ spotifyTrack: SpotifyTrack) -> Track {
        let singer = spotifyTrack.artists.map(\.name).joined(separator: ", ")
        let cover = spotifyTrack.album?.images.first?.url ?? ""
        return Track(
            id: stableId("track:\(spotifyTrack.id)"),
            title: String(spotifyTrack.name.prefix(128)),
            album: spotifyTrack.album?.name ?? "",
            singer: singer,
            coverUri: cover,
            url: buildPlayQuery(
                spotifyTrackId: spotifyTrack.id,
                title: spotifyTrack.name,
                artist: singer
            ),
            spotifyTrackId: spotifyTrack.id,
            explicit: spotifyTrack.explicit,
            durationMs: spotifyTrack.durationMs
        )
    }

    static func toAlbum(_ spotifyAlbum: SpotifyAlbum) -> Album {
        Album(
            id: stableId("album:\(spotifyAlbum.id)"),
            artists: spotifyAlbum.artists.map(\.name).joined(separator: ", "),
            coverUri: spotifyAlbum.images.first?.url ?? "",
            name: spotifyAlbum.name,
            time: spotifyAlbum.releaseDate ?? "",
            type: spotifyAlbum.albumType ?? ""
        )
    }

    static func toArtist(_ spotifyArtist: SpotifyArtist) -> Artist {
        Artist(
            name: spotifyArtist.name,
            coverUri: spotifyArtist.images.first?.url ?? "",
            id: spotifyArtist.id
        )
    }

    // MARK: - Search query building

    static func buildSearchQuery(track: SpotifyTrack) -> String {
        let artist = track.artists.first?.name ?? ""
        return artist.isEmpty ? track.name : "\(artist) \(track.name)"
    }

    // MARK: - Thumbnail helpers

    static func playlistThumbnail(_ playlist: SpotifyPlaylist) -> String? {
        playlist.images.first(where: { ($0.width ?? 0) >= 200 && ($0.width ?? 0) <= 400 })?.url
            ?? playlist.images.first?.url
    }

    static func trackThumbnail(_ track: SpotifyTrack) -> String? {
        track.album?.images.first(where: { ($0.width ?? 0) >= 200 && ($0.width ?? 0) <= 400 })?.url
            ?? track.album?.images.first?.url
    }

    // MARK: - Normalization & matching (for YouTube candidate scoring)

    static func normalizeTitle(_ title: String) -> String {
        var result = title.lowercased()
        for pattern in [featPattern, ftPattern, bracketPattern, remasterPattern, nonAlnumPattern, multiSpacePattern] {
            let range = NSRange(result.startIndex..., in: result)
            result = pattern.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    static func matchScore(
        spotifyTitle: String,
        spotifyArtist: String,
        spotifyDurationMs: Int,
        candidateTitle: String,
        candidateArtist: String,
        candidateDurationSec: Int?
    ) -> Double {
        let titleScore = bigramSimilarity(normalizeTitle(spotifyTitle), normalizeTitle(candidateTitle))
        let artistScore = bigramSimilarity(normalizeTitle(spotifyArtist), normalizeTitle(candidateArtist))
        let durationScore = computeDurationScore(spotifyDurationMs, candidateDurationSec)
        return titleScore * 0.45 + artistScore * 0.35 + durationScore * 0.20
    }

    // MARK: - Private

    private static func stableId(_ key: String) -> Int {
        var hasher = Hasher()
        hasher.combine(key)
        return hasher.finalize() & 0x7FFFFFFF
    }

    private static func bigramSimilarity(_ a: String, _ b: String) -> Double {
        if a == b { return 1.0 }
        guard a.count >= 2, b.count >= 2 else { return 0.0 }
        let aBigrams = Set(bigrams(a))
        let bBigrams = Set(bigrams(b))
        guard !aBigrams.isEmpty, !bBigrams.isEmpty else { return 0.0 }
        let intersection = aBigrams.filter(bBigrams.contains).count
        return Double(2 * intersection) / Double(aBigrams.count + bBigrams.count)
    }

    private static func bigrams(_ s: String) -> [String] {
        let chars = Array(s)
        return (0..<(chars.count - 1)).map { String(chars[$0...$0+1]) }
    }

    private static func computeDurationScore(_ spotifyMs: Int, _ candidateSec: Int?) -> Double {
        guard let candidateSec, spotifyMs > 0 else { return 0.5 }
        let diff = abs(spotifyMs / 1000 - candidateSec)
        switch diff {
        case ...2: return 1.0
        case ...5: return 0.8
        case ...10: return 0.5
        case ...30: return 0.2
        default: return 0.0
        }
    }
}
