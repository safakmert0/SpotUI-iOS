import Foundation

struct SpotifyRecommendations: Codable {
    let tracks: [SpotifyTrack]
    let seeds: [SpotifyRecommendationSeed]
}

struct SpotifyRecommendationSeed: Codable {
    let id: String?
    let type: String?
    let href: String?
}
