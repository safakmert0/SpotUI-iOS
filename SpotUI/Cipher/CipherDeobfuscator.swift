import Foundation

/// Orchestrates cipher deobfuscation and n-transform.
/// Port of CipherDeobfuscator.kt.
@MainActor
enum CipherDeobfuscator {
    private static var cipherWebView: CipherWebView?
    private static var currentHash: String?

    static func deobfuscateStreamUrl(signatureCipher: String, videoId: String) async -> String? {
        do {
            return try await deobfuscateInternal(signatureCipher, videoId: videoId, isRetry: false)
        } catch {
            PlayerJsFetcher.invalidateCache()
            closeWebView()
            do {
                return try await deobfuscateInternal(signatureCipher, videoId: videoId, isRetry: true)
            } catch {
                return nil
            }
        }
    }

    static func transformNParamInUrl(_ url: String) async -> String {
        guard let nMatch = url.firstMatch(of: /[?&]n=([^&]+)/) else { return url }
        let nValue = String(nMatch.1).removingPercentEncoding ?? String(nMatch.1)
        guard let webView = await getOrCreateWebView(forceRefresh: false) else { return url }
        guard webView.nFunctionAvailable else { return url }
        do {
            let transformed = try await webView.transformN(nValue)
            return url.replacingFirst(of: /([?&])n=[^&]+/, with: "$1n=\(transformed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? transformed)")
        } catch {
            return url
        }
    }

    private static func deobfuscateInternal(signatureCipher: String, videoId: String, isRetry: Bool) async throws -> String {
        let params = parseQueryParams(signatureCipher)
        guard let obfuscatedSig = params["s"], let baseUrl = params["url"] else {
            throw CipherError.sigNotAvailable
        }
        let sigParam = params["sp"] ?? "signature"
        guard let webView = await getOrCreateWebView(forceRefresh: isRetry) else {
            throw CipherError.sigNotAvailable
        }
        let deobfuscatedSig = try await webView.deobfuscateSignature(obfuscatedSig)
        let separator = baseUrl.contains("?") ? "&" : "?"
        return "\(baseUrl)\(separator)\(sigParam)=\(deobfuscatedSig.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? deobfuscatedSig)"
    }

    private static func getOrCreateWebView(forceRefresh: Bool) async -> CipherWebView? {
        if !forceRefresh, let existing = cipherWebView { return existing }
        if cipherWebView != nil { closeWebView() }
        guard let (playerJs, hash) = await PlayerJsFetcher.getPlayerJs(forceRefresh: forceRefresh) else { return nil }
        let sigInfo = FunctionNameExtractor.extractSigFunctionInfo(playerJs, knownHash: hash)
        let nFuncInfo = FunctionNameExtractor.extractNFunctionInfo(playerJs, knownHash: hash)
        guard let wv = try? await CipherWebView.create(playerJs: playerJs, sigInfo: sigInfo, nFuncInfo: nFuncInfo) else { return nil }
        cipherWebView = wv
        currentHash = hash
        return wv
    }

    private static func closeWebView() {
        cipherWebView?.close()
        cipherWebView = nil
        currentHash = nil
    }

    private static func parseQueryParams(_ query: String) -> [String: String] {
        var result: [String: String] = [:]
        for pair in query.split(separator: "&") {
            if let idx = pair.firstIndex(of: "=") {
                let key = String(pair[pair.startIndex..<idx]).removingPercentEncoding ?? String(pair[pair.startIndex..<idx])
                let value = String(pair[pair.index(after: idx)...]).removingPercentEncoding ?? String(pair[pair.index(after: idx)...])
                result[key] = value
            }
        }
        return result
    }
}
