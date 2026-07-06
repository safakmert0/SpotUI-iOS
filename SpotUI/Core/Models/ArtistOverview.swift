import Foundation

struct ArtistOverview: Codable {
    let id: String
    let name: String
    let verified: Bool
    let monthlyListeners: Int64?
    let biography: String?
    let headerImage: String
    let avatarImage: String
    let topTracks: [ArtistTrackUI]
    let popularReleases: [Album]
    let appearsOn: [Album]
    let relatedArtists: [Artist]

    init(
        id: String = "",
        name: String = "",
        verified: Bool = false,
        monthlyListeners: Int64? = nil,
        biography: String? = nil,
        headerImage: String = "",
        avatarImage: String = "",
        topTracks: [ArtistTrackUI] = [],
        popularReleases: [Album] = [],
        appearsOn: [Album] = [],
        relatedArtists: [Artist] = []
    ) {
        self.id = id
        self.name = name
        self.verified = verified
        self.monthlyListeners = monthlyListeners
        self.biography = biography
        self.headerImage = headerImage
        self.avatarImage = avatarImage
        self.topTracks = topTracks
        self.popularReleases = popularReleases
        self.appearsOn = appearsOn
        self.relatedArtists = relatedArtists
    }
}

struct ArtistTrackUI: Codable, Identifiable {
    let song: Track
    let playcount: Int64?

    var id: Int { song.id }
}
