import Foundation

/// Checks for app updates from GitHub releases. Port of UpdateChecker.kt.
enum UpdateChecker {

    struct UpdateInfo {
        let version: String
        let downloadUrl: String
        let fingerprint: String
    }

    private static let releaseAPI = "https://api.github.com/repos/safakmert0/SpotUI-iOS/releases/tags/Release"
    private static let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"

    static func check() async -> UpdateInfo? {
        guard let info = try? await fetchRelease() else { return nil }
        guard isNewer(remote: info.version, installed: currentVersion) else { return nil }
        let skipped = UserDefaults.standard.string(forKey: "skip_update_\(info.fingerprint)")
        if skipped != nil { return nil }
        return info
    }

    static func skipRelease(_ info: UpdateInfo) {
        UserDefaults.standard.set(info.fingerprint, forKey: "skip_update_\(info.fingerprint)")
    }

    private static func fetchRelease() async throws -> UpdateInfo {
        guard let url = URL(string: releaseAPI) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "UpdateChecker", code: -1)
        }
        let version = extractVersion(json["name"] as? String)
            ?? extractVersion(json["body"] as? String)
            ?? ""
        guard !version.isEmpty else { throw NSError(domain: "UpdateChecker", code: -2) }
        let assets = json["assets"] as? [[String: Any]]
        let ipaUrl = assets?.first { ($0["name"] as? String ?? "").hasSuffix(".ipa") }?["browser_download_url"] as? String
        let page = json["html_url"] as? String ?? "https://github.com/safakmert0/SpotUI-iOS/releases"
        return UpdateInfo(
            version: version,
            downloadUrl: ipaUrl ?? page,
            fingerprint: "\(json["id"] ?? 0):\(json["updated_at"] ?? ""):\(version)"
        )
    }

    private static func extractVersion(_ text: String?) -> String? {
        guard let text else { return nil }
        let pattern = /\d+(?:\.\d+)+/
        guard let match = text.firstMatch(of: pattern) else { return nil }
        return String(match.output)
    }

    private static func isNewer(remote: String, installed: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let i = installed.split(separator: ".").compactMap { Int($0) }
        for n in 0..<max(r.count, i.count) {
            let a = n < r.count ? r[n] : 0
            let b = n < i.count ? i[n] : 0
            if a != b { return a > b }
        }
        return false
    }
}
