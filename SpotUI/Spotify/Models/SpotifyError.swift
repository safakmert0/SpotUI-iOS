import Foundation

struct SpotifyErrorResponse: Codable {
    let error: SpotifyErrorBody
}

struct SpotifyErrorBody: Codable {
    let status: Int
    let message: String
    let reason: String?
}
