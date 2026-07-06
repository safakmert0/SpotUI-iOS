import Foundation

/// UserDefaults wrapper for app preferences (port of SettingsPref + related prefs).
final class UserPreferences {
    static let shared = UserPreferences()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let streamingQuality = "streamingQuality"
        static let downloadQuality = "downloadQuality"
        static let losslessEnabled = "losslessEnabled"
        static let losslessHiRes = "losslessHiRes"
        static let preloadEnabled = "preloadEnabled"
        static let webPlaybackEnabled = "webPlaybackEnabled"
        static let crossfadeEnabled = "crossfadeEnabled"
    }

    enum StreamingQuality: String, CaseIterable {
        case low, normal, high, lossless

        var audioQuality: String {
            switch self {
            case .low: return "LOW"
            case .normal: return "NORMAL"
            case .high: return "HIGH"
            case .lossless: return "LOSSLESS"
            }
        }

        var lossless: Bool { self == .lossless }
    }

    enum DownloadQuality: String, CaseIterable {
        case low, normal, high, lossless

        var audioQuality: String {
            switch self {
            case .low: return "LOW"
            case .normal: return "NORMAL"
            case .high: return "HIGH"
            case .lossless: return "LOSSLESS"
            }
        }
    }

    var streamingQuality: StreamingQuality {
        get {
            guard let raw = defaults.string(forKey: Keys.streamingQuality),
                  let q = StreamingQuality(rawValue: raw) else { return .normal }
            return q
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.streamingQuality) }
    }

    var downloadQuality: DownloadQuality {
        get {
            guard let raw = defaults.string(forKey: Keys.downloadQuality),
                  let q = DownloadQuality(rawValue: raw) else { return .high }
            return q
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.downloadQuality) }
    }

    var losslessEnabled: Bool {
        get { defaults.object(forKey: Keys.losslessEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.losslessEnabled) }
    }

    var losslessHiRes: Bool {
        get { defaults.object(forKey: Keys.losslessHiRes) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.losslessHiRes) }
    }

    var preloadEnabled: Bool {
        get { defaults.object(forKey: Keys.preloadEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.preloadEnabled) }
    }

    var webPlaybackEnabled: Bool {
        get { defaults.object(forKey: Keys.webPlaybackEnabled) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Keys.webPlaybackEnabled) }
    }

    var crossfadeEnabled: Bool {
        get { defaults.object(forKey: Keys.crossfadeEnabled) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Keys.crossfadeEnabled) }
    }

    // MARK: - Downloaded tracks

    private let downloadBasePath = "downloads"

    var downloadsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(downloadBasePath)
    }

    func isDownloaded(trackId: Int) -> Bool {
        let file = downloadsDirectory.appendingPathComponent("\(trackId).m4a")
        let flac = downloadsDirectory.appendingPathComponent("\(trackId).flac")
        return FileManager.default.fileExists(atPath: file.path) ||
               FileManager.default.fileExists(atPath: flac.path)
    }

    func downloadedPath(for trackId: Int) -> String? {
        let file = downloadsDirectory.appendingPathComponent("\(trackId).m4a")
        let flac = downloadsDirectory.appendingPathComponent("\(trackId).flac")
        if FileManager.default.fileExists(atPath: flac.path) { return flac.path }
        if FileManager.default.fileExists(atPath: file.path) { return file.path }
        return nil
    }

    // MARK: - Playback state restoration

    var lastPlayedQuery: String? {
        get { defaults.string(forKey: "lastPlayedQuery") }
        set { defaults.set(newValue, forKey: "lastPlayedQuery") }
    }

    var lastPlayedPositionMs: Int64 {
        get { defaults.object(forKey: "lastPlayedPositionMs") as? Int64 ?? 0 }
        set { defaults.set(newValue, forKey: "lastPlayedPositionMs") }
    }
}
