import Foundation

struct PlayerResponse: Codable {
    let streamingData: StreamingData?
    let videoDetails: VideoDetails?
    let playabilityStatus: PlayabilityStatus?
}

struct StreamingData: Codable {
    let adaptiveFormats: [AdaptiveFormat]?
    let hlsManifestUrl: String?
    let dashManifestUrl: String?
}

struct AdaptiveFormat: Codable {
    let itag: Int?
    let mimeType: String?
    let bitrate: Int?
    let width: Int?
    let height: Int?
    let contentLength: Int64?
    let url: String?
    let signatureCipher: String?
    let audioQuality: String?
    let audioChannels: Int?
    let audioSampleRate: String?
    let approxDurationMs: String?
    let loudnessDb: Double?

    var isAudioOnly: Bool {
        mimeType?.contains("audio") == true
    }
}

struct VideoDetails: Codable {
    let videoId: String?
    let title: String?
    let author: String?
    let lengthSeconds: String?
    let shortDescription: String?
    let channelId: String?
    let isLiveContent: Bool?
}

struct PlayabilityStatus: Codable {
    let status: String?
    let reason: String?
}
