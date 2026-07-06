import Foundation
import WebKit

/// WebView-based PoToken generator using BotGuard.
/// Port of PoTokenWebView.kt — uses WKWebView to run BotGuard and generate poTokens.
@MainActor
final class PoTokenWebView: NSObject {
    private var webView: WKWebView?
    private var minterContinuation: ((Result<PoTokenWebView, Error>) -> Void)?
    private var poTokenContinuations: [String: (Result<String, Error>) -> Void] = [:]
    private var expirationInstant: Date = .distantPast

    private static let googleAPIKey = "AIzaSyDyT5W0Jh49F30Pqqtyfdf7pDLFKLJoAnw"
    private static let requestKey = "O43z0dpjhgX20SCx4KAo"
    private static let userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.3"

    var isExpired: Bool { Date() > expirationInstant }

    static func getNewPoTokenGenerator() async throws -> PoTokenWebView {
        try await withCheckedThrowingContinuation { cont in
            let pot = PoTokenWebView()
            pot.minterContinuation = { result in
                switch result {
                case .success(let wv): cont.resume(returning: wv)
                case .failure(let err): cont.resume(throwing: err)
                }
            }
            pot.setupWebView()
            pot.loadHtmlAndObtainBotguard()
        }
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.javaScriptEnabled = true
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self
        let handler = PoTokenMessageHandler(generator: self)
        wv.configuration.userContentController.add(handler, name: "poTokenBridge")
        wv.customUserAgent = Self.userAgent
        self.webView = wv
    }

    private func loadHtmlAndObtainBotguard() {
        let html = """
        <!DOCTYPE html><html><head>
        <script src="https://www.youtube.com/api/jnn/v1/Create"></script>
        <script>
        function downloadAndRunBotguard() {
            fetch('https://www.youtube.com/api/jnn/v1/Create', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json+protobuf', 'x-goog-api-key': '\(Self.googleAPIKey)', 'x-user-agent': 'grpc-web-javascript/0.1' },
                body: JSON.stringify(["\(Self.requestKey)"])
            }).then(function(r) { return r.text(); }).then(function(body) {
                var data = JSON.parse(body);
                runBotGuard(data).then(function(result) {
                    this.webPoSignalOutput = result.webPoSignalOutput;
                    poTokenBridge.postMessage({type:'botguardResult', response: result.botguardResponse});
                }, function(error) {
                    poTokenBridge.postMessage({type:'initError', error: String(error)});
                });
            }).catch(function(e) { poTokenBridge.postMessage({type:'initError', error: String(e)}); });
        }
        </script></head><body>
        <script>downloadAndRunBotguard();</script>
        </body></html>
        """
        webView?.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com")!)
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
                minterContinuation?(.failure(PoTokenError.initializationFailed("GenerateIT request failed")))
                minterContinuation = nil
                return
            }
            guard let (integrityToken, expiresIn) = parseIntegrityTokenData(responseBody) else {
                minterContinuation?(.failure(PoTokenError.initializationFailed("Failed to parse integrity token")))
                minterContinuation = nil
                return
            }
            expirationInstant = Date().addingTimeInterval(Double(expiresIn) - 600)
            let js = """
            try {
                this.integrityToken = \(integrityToken)
                createPoTokenMinter(webPoSignalOutput, integrityToken).then(function() {
                    poTokenBridge.postMessage({type:'minterCreated'});
                }).catch(function(error) {
                    poTokenBridge.postMessage({type:'initError', error: String(error)});
                });
            } catch(error) { poTokenBridge.postMessage({type:'initError', error: String(error)}); }
            """
            webView?.evaluateJavaScript(js)
        }
    }

    private func parseIntegrityTokenData(_ body: String) -> (String, Int)? {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let response = json["response"] as? [String: Any],
              let innerResponse = response["innerResponse"] as? [String: Any],
              let integrityTokenResponse = innerResponse["integrityTokenResponse"] as? [String: Any],
              let integrityToken = integrityTokenResponse["integrityToken"] as? String,
              let expiresIn = integrityTokenResponse["expiresInSeconds"] as? Int else {
            return nil
        }
        return ("\(integrityToken)", expiresIn)
    }

    func generatePoToken(_ identifier: String) async throws -> String {
        return try await withCheckedThrowingContinuation { cont in
            poTokenContinuations[identifier] = cont
            let u8Array = identifier.utf8.map(String.init).joined(separator: ",")
            let js = """
            try {
                var u8 = new Uint8Array([\(u8Array)]);
                obtainPoToken(u8).then(function(poTokenU8) {
                    var str = poTokenU8.join(",");
                    poTokenBridge.postMessage({type:'poTokenResult', identifier:'\(identifier)', result: str});
                }).catch(function(error) {
                    poTokenBridge.postMessage({type:'poTokenError', identifier:'\(identifier)', error: String(error)});
                });
            } catch(error) { poTokenBridge.postMessage({type:'poTokenError', identifier:'\(identifier)', error: String(error)}); }
            """
            webView?.evaluateJavaScript(js)
        }
    }

    func close() {
        webView?.configuration.userContentController.removeAllUserScripts()
        webView?.loadHTMLString("", baseURL: nil)
        webView = nil
    }

    nonisolated func handleMessage(_ type: String, dict: [String: Any]) {
        Task { @MainActor in
            switch type {
            case "botguardResult":
                obtainIntegrityToken(dict["response"] as? String ?? "")
            case "initError":
                let error = PoTokenError.initializationFailed(dict["error"] as? String ?? "")
                minterContinuation?(.failure(error))
                minterContinuation = nil
            case "minterCreated":
                minterContinuation?(.success(self))
                minterContinuation = nil
            case "poTokenResult":
                let id = dict["identifier"] as? String ?? ""
                let result = dict["result"] as? String ?? ""
                let u8Values = result.split(separator: ",").compactMap { UInt8($0) }
                let base64 = Data(u8Values).base64EncodedString()
                poTokenContinuations[id]?(.success(base64))
                poTokenContinuations.removeValue(forKey: id)
            case "poTokenError":
                let id = dict["identifier"] as? String ?? ""
                poTokenContinuations[id]?(.failure(PoTokenError.initializationFailed(dict["error"] as? String ?? "")))
                poTokenContinuations.removeValue(forKey: id)
            default:
                break
            }
        }
    }
}

extension PoTokenWebView: WKNavigationDelegate {
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {}
}

class PoTokenMessageHandler: NSObject, WKScriptMessageHandler {
    let generator: PoTokenWebView
    init(generator: PoTokenWebView) { self.generator = generator }
    nonisolated func userContentController(_ uc: WKUserContentController, didReceive msg: WKScriptMessage) {
        guard let body = msg.body as? [String: Any], let type = body["type"] as? String else { return }
        generator.handleMessage(type, dict: body)
    }
}
