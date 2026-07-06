import Foundation

struct SpotifyUser: Codable {
    let id: String
    let displayName: String?
    let email: String?
    let images: [SpotifyImage]
    let product: String?
    let country: String?

    enum CodingKeys: String, CodingKey {
        case id, email, images, product, country
        case displayName = "display_name"
    }
}

struct SpotifyImage: Codable {
    let url: String
    let height: Int?
    let width: Int?
}
