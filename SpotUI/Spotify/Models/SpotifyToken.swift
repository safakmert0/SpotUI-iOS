import Foundation

struct SpotifyToken: Codable {
    let accessToken: String
    let tokenType: String
    let scope: String
    let expiresIn: Int
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case scope, expiresIn, refreshToken
        case accessToken = "access_token"
        case tokenType = "token_type"
    }
}

struct SpotifyInternalToken: Codable {
    let accessToken: String
    let accessTokenExpirationTimestampMs: Int64
    let isAnonymous: Bool
    let clientId: String
}
