import Foundation
import Security

/// Stores the logged-in Spotify sp_dc cookie in the Keychain.
/// Equivalent to Android's SpotifySession using SharedPreferences.
final class SpotifySession {
    static let shared = SpotifySession()

    private let service = "com.music.spotui.sp_dc"
    private let account = "spotify"

    var spDc: String {
        get { readFromKeychain() ?? "" }
        set { saveToKeychain(newValue.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }

    var isLoggedIn: Bool {
        !spDc.isEmpty
    }

    private func saveToKeychain(_ value: String) {
        guard let data = value.data(using: .utf8) else { return }
        deleteFromKeychain()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private func readFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    func clear() {
        deleteFromKeychain()
    }
}
