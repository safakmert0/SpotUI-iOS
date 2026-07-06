import Foundation
import WebKit

/// WebView-based PoToken generator using BotGuard.
/// Port of PoTokenWebView.kt — uses WKWebView to run BotGuard and generate poTokens.
@MainActor
final class PoTokenWebView: NSObject, WKScriptMessageHandler {
    private var webView: WKWebView?
    private var minterContinuation: CheckedContinuation<PoTokenWebView, Error>?
    private var poTokenContinuations: [String: CheckedContinuation<String, Error>] = [:]
    private var expirationInstant: Date = .distantPast

    private static let googleAPIKey = "AIzaSyDyT5W0Jh49F30Pqqtyfdf7pDLFKLJoAnw"
    private static let requestKey = "O43z0dpjhgX20SCx4KAo"
    private static let userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.3"

    var isExpired: Bool { Date() > expirationInstant }

    static func getNewPoTokenGenerator() async throws -> PoTokenWebView {
        try await withCheckedThrowingContinuation { cont in
            let pot = PoTokenWebView()
            pot.minterContinuation = cont
            pot.setupWebView()
            pot.loadHtmlAndObtainBotguard()
        }
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self
        wv.configuration.userContentController.add(self, name: "poTokenBridge")
        wv.customUserAgent = Self.userAgent
        self.webView = wv
    }

    private func loadHtmlAndObtainBotguard() {
        let html = """
        <!DOCTYPE html><html><head></head><body><script>
        function downloadAndRunBotguard() {
            fetch('https://www.youtube.com/api/jnn/v1/Create', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json+protobuf', 'x-goog-api-key': '\(Self.googleAPIKey)', 'x-user-agent': 'grpc-web-javascript/0.1' },
                body: JSON.stringify(["\(Self.requestKey)"])
            }).then(function(r) { return r.text(); }).then(function(body) {
                var data = JSON.parse(body);
                runBotGuard(data).then(function(result) {
                    this.webPoSignalOutput = result.webPoSignalOutput;
                    webkit.messageHandlers.poTokenBridge.postMessage({type:'botguardResult', response: result.botguardResponse});
                }, function(error) {
                    webkit.messageHandlers.poTokenBridge.postMessage({type:'initError', error: String(error)});
                });
            }).catch(function(e) { webkit.messageHandlers.poTokenBridge.postMessage({type:'initError', error: String(e)}); });
        }
        downloadAndRunBotguard();
        </script></body></html>
        """
        webView?.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com"))
    }

    private func obtainIntegrityToken(_ botguardResponse: String) {
        let body = "[ \"\(Self.requestKey)\", \"\(botguardResponse)\" ]"
        guard let url = URL(string: "https://www.youtube.com/api/jnn/v1/GenerateIT") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body.data(using: .utf8)
        request.setValue("application/json+protobuf", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.googleAPIKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("grpc-web-javascript/0.1", forHTTPHeaderField: "x-user-agent")
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")

        Task {
            guard let (data, _) = try? await URLSession.shared.data(for: request),
                  let responseBody = String(data: data, encoding: .utf8) else {
                minterContinuation?.resume(throwing: PoTokenError.initializationFailed("GenerateIT failed"))
                minterContinuation = nil
                return
            }
            guard let parsed = parseGenerateITResponse(responseBody) else {
                minterContinuation?.resume(throwing: PoTokenError.initializationFailed("Parse failed"))
                minterContinuation = nil
                return
            }
            expirationInstant = Date().addingTimeInterval(Double(parsed.expiresIn) - 600)
            let js = """
            try {
                this.integrityToken = \(parsed.token)
                createPoTokenMinter(webPoSignalOutput, integrityToken).then(function() {
                    webkit.messageHandlers.poTokenBridge.postMessage({type:'minterCreated'});
                }).catch(function(error) {
                    webkit.messageHandlers.poTokenBridge.postMessage({type:'initError', error: String(error)});
                });
            } catch(error) { webkit.messageHandlers.poTokenBridge.postMessage({type:'initError', error: String(error)}); }
            """
            webView?.evaluateJavaScript(js, completionHandler: nil)
        }
    }

    private struct IntegrityParsed {
        let token: String
        let expiresIn: Int
    }

    private func parseGenerateITResponse(_ body: String) -> IntegrityParsed? {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let response = json["response"] as? [String: Any],
           let inner = response["innerResponse"] as? [String: Any],
           let itr = inner["integrityTokenResponse"] as? [String: Any],
           let token = itr["integrityToken"] as? String,
           let expiresIn = itr["expiresInSeconds"] as? Int {
            return IntegrityParsed(token: token, expiresIn: expiresIn)
        }
        if let token = json["integrityToken"] as? String, let expiresIn = json["expiresInSeconds"] as? Int {
            return IntegrityParsed(token: token, expiresIn: expiresIn)
        }
        return nil
    }

    func generatePoToken(_ identifier: String) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            poTokenContinuations[identifier] = cont
            let u8Array = identifier.utf8.map(String.init).joined(separator: ",")
            let js = """
            try {
                var u8 = new Uint8Array([\(u8Array)]);
                obtainPoToken(u8).then(function(poTokenU8) {
                    var str = poTokenU8.join(",");
                    webkit.messageHandlers.poTokenBridge.postMessage({type:'poTokenResult', identifier:'\(identifier)', result: str});
                }).catch(function(error) {
                    webkit.messageHandlers.poTokenBridge.postMessage({type:'poTokenError', identifier:'\(identifier)', error: String(error)});
                });
            } catch(error) { webkit.messageHandlers.poTokenBridge.postMessage({type:'poTokenError', identifier:'\(identifier)', error: String(error)}); }
            """
            webView?.evaluateJavaScript(js, completionHandler: nil)
        }
    }

    func close() {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "poTokenBridge")
        webView?.loadHTMLString("", baseURL: nil)
        webView = nil
    }

    func userContentController(_ uc: WKUserContentController, didReceive msg: WKScriptMessage) {
        guard let body = msg.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "botguardResult":
            obtainIntegrityToken(body["response"] as? String ?? "")
        case "initError":
            minterContinuation?.resume(throwing: PoTokenError.initializationFailed(body["error"] as? String ?? ""))
            minterContinuation = nil
        case "minterCreated":
            minterContinuation?.resume(returning: self)
            minterContinuation = nil
        case "poTokenResult":
            let id = body["identifier"] as? String ?? ""
            let result = body["result"] as? String ?? ""
            let u8Values = result.components(separatedBy: ",").compactMap { UInt8($0) }
            let base64 = Data(u8Values).base64EncodedString()
            poTokenContinuations[id]?.resume(returning: base64)
            poTokenContinuations.removeValue(forKey: id)
        case "poTokenError":
            let id = body["identifier"] as? String ?? ""
            poTokenContinuations[id]?.resume(throwing: PoTokenError.initializationFailed(body["error"] as? String ?? ""))
            poTokenContinuations.removeValue(forKey: id)
        default:
            break
        }
    }
}

extension PoTokenWebView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {}
}
