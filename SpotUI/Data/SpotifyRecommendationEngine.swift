import Foundation

/// Personalized recommendation engine. Port of SpotifyRecommendationEngine.kt.
/// Builds its own recommender from endpoints that still work with cookie tokens:
/// 1. Taste profile from user's top tracks/artists
/// 2. Candidate generation from seed-artist top tracks, same-album, genre-neighbors, user top pool
/// 3. Composite scoring with source relevance, artist affinity, genre overlap, popularity, recency
/// 4. Diversification with per-artist cap and bucket interleaving
enum SpotifyRecommendationEngine {

    private static let profileTTL: TimeInterval = 6 * 3600
    private static let maxTracksPerArtist = 3

    private static let wSource: Double = 0.25
    private static let wAffinity: Double = 0.30
    private static let wGenre: Double = 0.20
    private static let wPopularity: Double = 0.10
    private static let wRecency: Double = 0.15

    private static var artistAffinityMap: [String: Double] = [:]
    private static var artistGenreMap: [String: Set<String>] = [:]
    private static var topTrackPool: [SpotifyTrack] = []
    private static var shortTermArtistIds: Set<String> = []
    private static var lastProfileRefresh: Date = .distantPast

    private enum Bucket: Double {
        case seedArtist = 1.0
        case sameAlbum = 0.85
        case genreNeighbor = 0.65
        case userTop = 0.45
    }

    private struct ScoredCandidate {
        let track: SpotifyTrack
        let bucket: Bucket
        let sourceScore: Double
        let artistAffinity: Double
        let genreOverlap: Double
        let popularitySimilarity: Double
        let recencyBoost: Double

        var finalScore: Double {
            wSource * sourceScore +
            wAffinity * artistAffinity +
            wGenre * genreOverlap +
            wPopularity * popularitySimilarity +
            wRecency * recencyBoost
        }
    }

    private static func ensureProfileLoaded() async -> Bool {
        if Date().timeIntervalSince(lastProfileRefresh) < profileTTL && !artistAffinityMap.isEmpty {
            return true
        }
        guard SpotifyAPI.accessToken != nil else { return false }

        do {
            let profileTracks = try await SpotifyAPI.topTracks(timeRange: "medium_term", limit: 50)
            let profileArtists = try await SpotifyAPI.topArtists(timeRange: "medium_term", limit: 50)

            if profileTracks.isEmpty && profileArtists.isEmpty { return false }

            var affinityBuilder: [String: Double] = [:]
            var genreBuilder: [String: Set<String>] = [:]

            for (index, artist) in profileArtists.enumerated() {
                guard !artist.id.isEmpty else { continue }
                let positionScore = 1.0 - (Double(index) / Double(max(profileArtists.count, 1)))
                affinityBuilder[artist.id, default: 0] += positionScore * 2.0
                if !artist.genres.isEmpty {
                    genreBuilder[artist.id, default: []].formUnion(artist.genres)
                }
            }
            for (index, track) in profileTracks.enumerated() {
                let positionScore = 1.0 - (Double(index) / Double(max(profileTracks.count, 1)))
                for artist in track.artists {
                    guard let artistId = artist.id else { continue }
                    affinityBuilder[artistId, default: 0] += positionScore * 1.0
                }
            }

            let maxAffinity = affinityBuilder.values.max() ?? 1.0
            let normalized = maxAffinity > 0
                ? affinityBuilder.mapValues { $0 / maxAffinity }
                : affinityBuilder

            var seenIds = Set<String>()
            let trackPool = profileTracks.filter { $0.id.isEmpty ? false : seenIds.insert($0.id).inserted }

            artistAffinityMap = normalized
            artistGenreMap = genreBuilder
            topTrackPool = trackPool
            shortTermArtistIds = Set(profileArtists.prefix(10).map(\.id).filter { !$0.isEmpty })
            lastProfileRefresh = Date()
            return true
        } catch {
            return false
        }
    }

    static func getRecommendations(seedTrack: SpotifyTrack, limit: Int = 25) async -> [SpotifyTrack] {
        guard await ensureProfileLoaded() else { return [] }

        var candidates: [ScoredCandidate] = []
        var seenIds = Set<String>()
        seenIds.insert(seedTrack.id)
        let seedArtistIds = Set(seedTrack.artists.compactMap(\.id))
        let seedPopularity = seedTrack.popularity ?? 50
        let seedGenres = Set(seedArtistIds.flatMap { artistGenreMap[$0] ?? [] })

        // Source 1: seed-artist top tracks
        for artistId in seedArtistIds.prefix(2) {
            if let tracks = try? await SpotifyAPI.artistTopTracks(artistId: artistId) {
                for track in tracks where !track.id.isEmpty && seenIds.insert(track.id).inserted {
                    candidates.append(buildCandidate(track, bucket: .seedArtist, seedPopularity: seedPopularity, seedGenres: seedGenres))
                }
            }
        }

        // Source 2: same-album tracks
        if let albumId = seedTrack.album?.id {
            if let albumPaging = try? await SpotifyAPI.albumTracks(albumId: albumId) {
                for track in albumPaging.items where !track.id.isEmpty && seenIds.insert(track.id).inserted {
                    candidates.append(buildCandidate(track, bucket: .sameAlbum, seedPopularity: seedPopularity, seedGenres: seedGenres))
                }
            }
        }

        // Source 3: genre-neighbor artist top tracks
        let neighbors = findGenreNeighbors(seedArtistIds: seedArtistIds, seedGenres: seedGenres)
        for artistId in neighbors.prefix(4) {
            if let tracks = try? await SpotifyAPI.artistTopTracks(artistId: artistId) {
                for track in tracks where !track.id.isEmpty && seenIds.insert(track.id).inserted {
                    candidates.append(buildCandidate(track, bucket: .genreNeighbor, seedPopularity: seedPopularity, seedGenres: seedGenres))
                }
            }
        }

        // Source 4: user's top-track pool
        for track in topTrackPool where !track.id.isEmpty && seenIds.insert(track.id).inserted {
            candidates.append(buildCandidate(track, bucket: .userTop, seedPopularity: seedPopularity, seedGenres: seedGenres))
        }

        return diversify(candidates: candidates.sorted { $0.finalScore > $1.finalScore }, limit: limit)
    }

    private static func buildCandidate(
        _ track: SpotifyTrack,
        bucket: Bucket,
        seedPopularity: Int,
        seedGenres: Set<String>
    ) -> ScoredCandidate {
        let trackArtistIds = track.artists.compactMap(\.id)
        let affinity = trackArtistIds.map { artistAffinityMap[$0] ?? 0 }.max() ?? 0
        let trackGenres = Set(trackArtistIds.flatMap { artistGenreMap[$0] ?? [] })
        let genreOverlap: Double
        if !seedGenres.isEmpty && !trackGenres.isEmpty {
            genreOverlap = Double(seedGenres.intersection(trackGenres).count) / Double(seedGenres.union(trackGenres).count)
        } else {
            genreOverlap = 0
        }
        let popDiff = abs((track.popularity ?? 50) - seedPopularity)
        let popSimilarity = 1.0 - Double(popDiff) / 100.0
        let recency = trackArtistIds.contains { shortTermArtistIds.contains($0) } ? 1.0 : 0.0
        return ScoredCandidate(track: track, bucket: bucket, sourceScore: bucket.rawValue, artistAffinity: affinity, genreOverlap: genreOverlap, popularitySimilarity: popSimilarity, recencyBoost: recency)
    }

    private static func findGenreNeighbors(seedArtistIds: Set<String>, seedGenres: Set<String>) -> [String] {
        if seedGenres.isEmpty {
            return artistAffinityMap.filter { !seedArtistIds.contains($0.key) }
                .sorted { $0.value > $1.value }
                .prefix(5)
                .map(\.key)
        }
        return artistGenreMap.filter { !seedArtistIds.contains($0.key) }
            .map { (artistId, genres) -> (String, Double) in
                let intersection = Double(seedGenres.intersection(genres).count)
                let union = Double(seedGenres.union(genres).count)
                let jaccard = union > 0 ? intersection / union : 0
                let affinity = artistAffinityMap[artistId] ?? 0
                return (artistId, jaccard * 0.6 + affinity * 0.4)
            }
            .filter { $0.1 > 0.05 }
            .sorted { $0.1 > $1.1 }
            .prefix(6)
            .map(\.0)
    }

    private static func diversify(candidates: [ScoredCandidate], limit: Int) -> [SpotifyTrack] {
        var result: [SpotifyTrack] = []
        var artistCount: [String: Int] = [:]
        var lastBuckets: [Bucket] = []
        var usedIndices = Set<Int>()

        while result.count < limit && usedIndices.count < candidates.count {
            let preferDifferentBucket = lastBuckets.count >= 3 && Set(lastBuckets.suffix(3)).count == 1

            var bestIndex = -1
            for i in candidates.indices {
                if usedIndices.contains(i) { continue }
                let candidate = candidates[i]
                let mainArtist = candidate.track.artists.first?.id ?? ""
                if (artistCount[mainArtist] ?? 0) >= maxTracksPerArtist { continue }
                if preferDifferentBucket && !lastBuckets.isEmpty {
                    if candidate.bucket != lastBuckets.last { bestIndex = i; break }
                    if bestIndex == -1 { bestIndex = i }
                } else {
                    bestIndex = i; break
                }
            }
            if bestIndex == -1 { break }

            let chosen = candidates[bestIndex]
            usedIndices.insert(bestIndex)
            result.append(chosen.track)
            let mainArtist = chosen.track.artists.first?.id ?? ""
            artistCount[mainArtist, default: 0] += 1
            lastBuckets.append(chosen.bucket)
            if lastBuckets.count > 5 { lastBuckets.removeFirst() }
        }
        return result
    }

    static func invalidateProfile() {
        lastProfileRefresh = .distantPast
        artistAffinityMap = [:]
        artistGenreMap = [:]
        topTrackPool = []
        shortTermArtistIds = []
    }
}
