import Foundation

struct PoTokenResult {
    let playerPot: String
    let streamingPot: String
}

enum PoTokenError: Error, LocalizedError {
    case webViewNotSupported
    case initializationFailed(String)
    var errorDescription: String? {
        switch self {
        case .webViewNotSupported: return "PoToken WebView not supported"
        case .initializationFailed(let msg): return "PoToken init failed: \(msg)"
        }
    }
}
