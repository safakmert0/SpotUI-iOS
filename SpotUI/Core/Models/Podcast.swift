import Foundation

struct Podcast: Identifiable, Codable {
    let id: String
    let name: String
    let publisher: String
    let coverUri: String

    init(id: String = "", name: String = "", publisher: String = "", coverUri: String = "") {
        self.id = id
        self.name = name
        self.publisher = publisher
        self.coverUri = coverUri
    }
}
