import Foundation

struct Album: Identifiable, Hashable, Codable {
    let id: Int
    let artists: String
    let coverUri: String
    let name: String
    let time: String
    let type: String

    init(
        id: Int = -1,
        artists: String = "",
        coverUri: String = "",
        name: String = "",
        time: String = "",
        type: String = ""
    ) {
        self.id = id
        self.artists = artists
        self.coverUri = coverUri
        self.name = name
        self.time = time
        self.type = type
    }
}
