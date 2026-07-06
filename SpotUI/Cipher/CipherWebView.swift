import Foundation
import WebKit

/// WebView-based cipher executor for YouTube stream URL deobfuscation.
/// Port of CipherWebView.kt — uses WKWebView to execute signature decipher and n-transform.
@MainActor
final class CipherWebView: NSObject, WKScriptMessageHandler {
    private var webView: WKWebView?
    private var sigContinuation: CheckedContinuation<String, Error>?
    private var nContinuation: CheckedContinuation<String, Error>?
    private var initContinuation: CheckedContinuation<CipherWebView, Error>?

    var nFunctionAvailable = false
    var sigFunctionAvailable = false

    private let playerJs: String
    private let sigInfo: FunctionNameExtractor.SigFunctionInfo?
    private let nFuncInfo: FunctionNameExtractor.NFunctionInfo?

    private init(playerJs: String, sigInfo: FunctionNameExtractor.SigFunctionInfo?, nFuncInfo: FunctionNameExtractor.NFunctionInfo?) {
        self.playerJs = playerJs
        self.sigInfo = sigInfo
        self.nFuncInfo = nFuncInfo
        super.init()
    }

    static func create(playerJs: String, sigInfo: FunctionNameExtractor.SigFunctionInfo?, nFuncInfo: FunctionNameExtractor.NFunctionInfo?) async throws -> CipherWebView {
        let wv = CipherWebView(playerJs: playerJs, sigInfo: sigInfo, nFuncInfo: nFuncInfo)
        return try await withCheckedThrowingContinuation { cont in
            wv.initContinuation = cont
            wv.setupAndLoad()
        }
    }

    private func setupAndLoad() {
        let config = WKWebViewConfiguration()
        let wv = WKWebView(frame: CGRect(x: 0, y: -300, width: 320, height: 240), configuration: config)
        wv.navigationDelegate = self
        wv.configuration.userContentController.add(self, name: "cipherBridge")
        self.webView = wv

        let exportSig: String
        if let sig = sigInfo {
            if let args = sig.constantArgs, let prep = sig.preprocessFunc, let prepArgs = sig.preprocessArgs {
                let constStr = args.map(String.init).joined(separator: ", ")
                let prepStr = prepArgs.map(String.init).joined(separator: ", ")
                exportSig = "window._cipherSigFunc = function(sig) { return \(sig.name)(\(constStr), \(preprocessFuncName(prep))(\(prepStr), sig)); };"
            } else if let args = sig.constantArgs {
                let argsStr = args.map(String.init).joined(separator: ", ")
                exportSig = "window._cipherSigFunc = function(sig) { return \(sig.name)(\(argsStr), sig); };"
            } else {
                exportSig = "window._cipherSigFunc = typeof \(sig.name) !== 'undefined' ? \(sig.name) : null;"
            }
        } else {
            exportSig = ""
        }

        let exportN: String
        if let nf = nFuncInfo {
            if let args = nf.constantArgs {
                let argsStr = args.map(String.init).joined(separator: ", ")
                exportN = "window._nTransformFunc = function(n) { return \(nf.name)(\(argsStr), n); };"
            } else if let idx = nf.arrayIndex {
                exportN = "window._nTransformFunc = typeof \(nf.name) !== 'undefined' ? \(nf.name)[\(idx)] : null;"
            } else {
                exportN = "window._nTransformFunc = typeof \(nf.name) !== 'undefined' ? \(nf.name) : null;"
            }
        } else {
            exportN = ""
        }

        let exports = [exportSig, exportN].filter { !$0.isEmpty }.joined(separator: " ")
        let exportCode = !exports.isEmpty ? "; \(exports)" : ""
        let marker = "})(_yt_player);"
        let modifiedJs: String
        if playerJs.contains(marker) {
            modifiedJs = playerJs.replacingOccurrences(of: marker, with: "\(exportCode) \(marker)")
        } else {
            modifiedJs = playerJs + "\n" + exportCode
        }

        let escapedJs = modifiedJs.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'").replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: "\r", with: "\\r")

        let html = """
        <!DOCTYPE html><html><head><script>
        function deobfuscateSig(funcName, constantArg, obfuscatedSig) {
            try {
                var func = window._cipherSigFunc;
                if (typeof func !== 'function') { webkit.messageHandlers.cipherBridge.postMessage({type:'sigError', error:'func not found'}); return; }
                var result;
                if (func.length === 1) { result = func(obfuscatedSig); }
                else if (constantArg !== null) { result = func(constantArg, obfuscatedSig); }
                else { result = func(obfuscatedSig); }
                if (result == null) { webkit.messageHandlers.cipherBridge.postMessage({type:'sigError', error:'null result'}); return; }
                webkit.messageHandlers.cipherBridge.postMessage({type:'sigResult', result: String(result)});
            } catch(e) { webkit.messageHandlers.cipherBridge.postMessage({type:'sigError', error: String(e)}); }
        }
        function transformN(nValue) {
            try {
                var func = window._nTransformFunc;
                if (typeof func !== 'function') { webkit.messageHandlers.cipherBridge.postMessage({type:'nError', error:'func not found'}); return; }
                var result = func(nValue);
                if (result == null) { webkit.messageHandlers.cipherBridge.postMessage({type:'nError', error:'null result'}); return; }
                webkit.messageHandlers.cipherBridge.postMessage({type:'nResult', result: String(result)});
            } catch(e) { webkit.messageHandlers.cipherBridge.postMessage({type:'nError', error: String(e)}); }
        }
        function discoverAndInit() {
            var sigOk = typeof window._cipherSigFunc === 'function';
            var nOk = false;
            if (typeof window._nTransformFunc === 'function') {
                try {
                    var test = window._nTransformFunc('KdrqFlzJXl9EcCwlmEy');
                    if (typeof test === 'string' && test !== 'KdrqFlzJXl9EcCwlmEy' && /^[a-zA-Z0-9_-]+$/.test(test)) { nOk = true; }
                    else { window._nTransformFunc = null; }
                } catch(e) { window._nTransformFunc = null; }
            }
            if (!nOk) {
                try {
                    var keys = Object.getOwnPropertyNames(window);
                    for (var i = 0; i < keys.length; i++) {
                        try {
                            var fn = window[keys[i]];
                            if (typeof fn !== 'function' || fn.length !== 1) continue;
                            var r = fn('T2Xw3pWQ_Wk0xbOg');
                            if (typeof r === 'string' && r !== 'T2Xw3pWQ_Wk0xbOg' && r.length >= 5 && /^[a-zA-Z0-9_-]+$/.test(r)) {
                                window._nTransformFunc = fn; nOk = true; break;
                            }
                        } catch(e) {}
                    }
                } catch(e) {}
            }
            webkit.messageHandlers.cipherBridge.postMessage({type:'initDone', sigOk: sigOk, nOk: nOk});
        }
        </script></head><body><script>
        var js = '\(escapedJs)';
        var s = document.createElement('script');
        s.textContent = js;
        document.head.appendChild(s);
        discoverAndInit();
        </script></body></html>
        """

        wv.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com"))
    }

    private func preprocessFuncName(_ name: String) -> String { name }

    func deobfuscateSignature(_ obfuscatedSig: String) async throws -> String {
        guard sigFunctionAvailable else { throw CipherError.sigNotAvailable }
        let constArgJs = sigInfo.map { $0.constantArg.map(String.init) ?? "null" } ?? "null"
        let escapedSig = obfuscatedSig.replacingOccurrences(of: "'", with: "\\'")
        let js = "deobfuscateSig('\(sigInfo?.name ?? "")', \(constArgJs), '\(escapedSig)')"
        return try await withCheckedThrowingContinuation { cont in
            sigContinuation = cont
            webView?.evaluateJavaScript(js)
        }
    }

    func transformN(_ nValue: String) async throws -> String {
        guard nFunctionAvailable else { throw CipherError.nNotAvailable }
        let escaped = nValue.replacingOccurrences(of: "'", with: "\\'")
        let js = "transformN('\(escaped)')"
        return try await withCheckedThrowingContinuation { cont in
            nContinuation = cont
            webView?.evaluateJavaScript(js)
        }
    }

    func close() {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "cipherBridge")
        webView?.loadHTMLString("", baseURL: nil)
        webView = nil
    }

    func userContentController(_ uc: WKUserContentController, didReceive msg: WKScriptMessage) {
        guard let body = msg.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "sigResult":
            sigContinuation?.resume(returning: body["result"] as? String ?? "")
            sigContinuation = nil
        case "sigError":
            sigContinuation?.resume(throwing: CipherError.sigFailed(body["error"] as? String ?? ""))
            sigContinuation = nil
        case "nResult":
            nContinuation?.resume(returning: body["result"] as? String ?? "")
            nContinuation = nil
        case "nError":
            nContinuation?.resume(throwing: CipherError.nFailed(body["error"] as? String ?? ""))
            nContinuation = nil
        case "initDone":
            sigFunctionAvailable = body["sigOk"] as? Bool ?? false
            nFunctionAvailable = body["nOk"] as? Bool ?? false
            initContinuation?.resume(returning: self)
            initContinuation = nil
        default:
            break
        }
    }
}

extension CipherWebView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {}
}

enum CipherError: Error, LocalizedError {
    case sigNotAvailable
    case nNotAvailable
    case sigFailed(String)
    case nFailed(String)
    var errorDescription: String? {
        switch self {
        case .sigNotAvailable: return "Signature function not available"
        case .nNotAvailable: return "N-transform function not available"
        case .sigFailed(let msg): return "Sig failed: \(msg)"
        case .nFailed(let msg): return "N-transform failed: \(msg)"
        }
    }
}
