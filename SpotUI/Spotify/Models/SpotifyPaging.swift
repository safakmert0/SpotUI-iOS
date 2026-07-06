import Foundation

struct SpotifyPaging<T: Codable>: Codable {
    let items: [T]
    let total: Int
    let limit: Int
    let offset: Int
    let next: String?
    let previous: String?
    let href: String?

    init(
        items: [T] = [],
        total: Int = 0,
        limit: Int = 20,
        offset: Int = 0,
        next: String? = nil,
        previous: String? = nil,
        href: String? = nil
    ) {
        self.items = items
        self.total = total
        self.limit = limit
        self.offset = offset
        self.next = next
        self.previous = previous
        self.href = href
    }
}
