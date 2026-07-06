import Foundation

struct Artist: Identifiable, Hashable, Codable {
    let name: String
    let coverUri: String
    let id: String

    init(name: String = "", coverUri: String = "", id: String = "") {
        self.name = name
        self.coverUri = coverUri
        self.id = id
    }
}
