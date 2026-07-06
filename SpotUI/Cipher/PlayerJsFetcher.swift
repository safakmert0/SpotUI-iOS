import Foundation

/// Fetches and caches YouTube's player.js for cipher operations.
/// Port of PlayerJsFetcher.kt.
enum PlayerJsFetcher {
    private static let iframeAPIURL = "https://www.youtube.com/iframe_api"
    private static let playerJsTemplate = "https://www.youtube.com/s/player/%@/player_ias.vflset/en_GB/base.js"
    private static let cacheTTL: TimeInterval = 6 * 3600
    private static let hashPattern = /\/s\/player\/([a-zA-Z0-9_-]+)\//

    private static let cacheDir: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("cipher_cache", isDirectory: true)
    }()

    static func getPlayerJs(forceRefresh: Bool = false) async -> (String, String)? {
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        if !forceRefresh, let cached = readFromCache() {
            return cached
        }

        guard let hash = await fetchPlayerHash() else { return nil }
        guard let playerJs = await downloadPlayerJs(hash: hash) else { return nil }

        writeToCache(hash: hash, playerJs: playerJs)
        return (playerJs, hash)
    }

    static func invalidateCache() {
        try? FileManager.default.removeItem(at: cacheDir)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    private static func readFromCache() -> (String, String)? {
        let hashFile = cacheDir.appendingPathComponent("current_hash.txt")
        guard let data = try? String(contentsOf: hashFile, encoding: .utf8) else { return nil }
        let parts = data.split(separator: "\n")
        guard parts.count >= 2, let ts = Double(parts[1]) else { return nil }
        let age = Date().timeIntervalSince1970 - ts
        guard age < cacheTTL else { return nil }
        let file = cacheDir.appendingPathComponent("player_\(parts[0]).js")
        guard let js = try? String(contentsOf: file, encoding: .utf8), !js.isEmpty else { return nil }
        return (js, String(parts[0]))
    }

    private static func writeToCache(hash: String, playerJs: String) {
        let hashFile = cacheDir.appendingPathComponent("current_hash.txt")
        let content = "\(hash)\n\(Int(Date().timeIntervalSince1970))"
        try? content.write(to: hashFile, atomically: true, encoding: .utf8)
        let file = cacheDir.appendingPathComponent("player_\(hash).js")
        try? playerJs.write(to: file, atomically: true, encoding: .utf8)
    }

    private static func fetchPlayerHash() async -> String? {
        guard let url = URL(string: iframeAPIURL) else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let body = String(data: data, encoding: .utf8) else { return nil }
        return body.firstMatch(of: hashPattern).map { String($0.1) }
    }

    private static func downloadPlayerJs(hash: String) async -> String? {
        let urlString = String(format: playerJsTemplate, hash)
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
