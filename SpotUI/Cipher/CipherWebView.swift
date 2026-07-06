import Foundation
import WebKit

/// WebView-based cipher executor for YouTube stream URL deobfuscation.
/// Port of CipherWebView.kt — uses WKWebView to execute signature decipher and n-transform.
@MainActor
final class CipherWebView: NSObject {
    private var webView: WKWebView?
    private var sigContinuation: ((Result<String, Error>) -> Void)?
    private var nContinuation: ((Result<String, Error>) -> Void)?
    private var initContinuation: ((Result<CipherWebView, Error>) -> Void)?

    var nFunctionAvailable = false
    var sigFunctionAvailable = false
    var usingHardcodedMode = false

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
        let webView = CipherWebView(playerJs: playerJs, sigInfo: sigInfo, nFuncInfo: nFuncInfo)
        return try await withCheckedThrowingContinuation { cont in
            webView.initContinuation = { result in
                switch result {
                case .success(let wv): cont.resume(returning: wv)
                case .failure(let err): cont.resume(throwing: err)
                }
            }
            webView.setupWebView()
            webView.loadPlayerJs()
        }
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.javaScriptEnabled = true
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self
        let handler = CipherMessageHandler(cipher: self)
        wv.configuration.userContentController.add(handler, name: "cipherBridge")
        self.webView = wv
    }

    private func loadPlayerJs() {
        let sigExport: String
        if let sig = sigInfo {
            if let constArgs = sig.constantArgs, let preprocess = sig.preprocessFunc, let prepArgs = sig.preprocessArgs {
                let constStr = constArgs.map(String.init).joined(separator: ", ")
                let prepStr = prepArgs.map(String.init).joined(separator: ", ")
                sigExport = "window._cipherSigFunc = function(sig) { return \(sig.name)(\(constStr), \(preprocess)(\(prepStr, sig))); };"
            } else if let constArgs = sig.constantArgs {
                let argsStr = constArgs.map(String.init).joined(separator: ", ")
                sigExport = "window._cipherSigFunc = function(sig) { return \(sig.name)(\(argsStr), sig); };"
            } else if sig.isHardcoded {
                sigExport = "window._cipherSigFunc = typeof \(sig.name) !== 'undefined' ? \(sig.name) : null;"
            } else {
                sigExport = "window._cipherSigFunc = typeof \(sig.name) !== 'undefined' ? \(sig.name) : null;"
            }
        } else {
            sigExport = ""
        }

        let nExport: String
        if let nFunc = nFuncInfo {
            if let constArgs = nFunc.constantArgs {
                let argsStr = constArgs.map(String.init).joined(separator: ", ")
                nExport = "window._nTransformFunc = function(n) { return \(nFunc.name)(\(argsStr), n); };"
            } else if let idx = nFunc.arrayIndex {
                nExport = "window._nTransformFunc = typeof \(nFunc.name) !== 'undefined' ? \(nFunc.name)[\(idx)] : null;"
            } else {
                nExport = "window._nTransformFunc = typeof \(nFunc.name) !== 'undefined' ? \(nFunc.name) : null;"
            }
        } else {
            nExport = ""
        }

        let exports = [sigExport, nExport].filter { !$0.isEmpty }.joined(separator: " ")
        let exportCode = !exports.isEmpty ? "; \(exports)" : ""
        let modifiedJs = playerJs.replacingOccurrences(of: "})(_yt_player);", with: "\(exportCode })(_yt_player);")

        let html = """
        <!DOCTYPE html><html><head><script>
        function deobfuscateSig(funcName, constantArg, obfuscatedSig) {
            try {
                var func = window._cipherSigFunc;
                if (typeof func !== 'function') { cipherBridge.postMessage({type:'sigError', error:'func not found'}); return; }
                var result;
                if (func.length === 1) { result = func(obfuscatedSig); }
                else if (constantArg !== null) { result = func(constantArg, obfuscatedSig); }
                else { result = func(obfuscatedSig); }
                if (result == null) { cipherBridge.postMessage({type:'sigError', error:'null result'}); return; }
                cipherBridge.postMessage({type:'sigResult', result: String(result)});
            } catch(e) { cipherBridge.postMessage({type:'sigError', error: String(e)}); }
        }
        function transformN(nValue) {
            try {
                var func = window._nTransformFunc;
                if (typeof func !== 'function') { cipherBridge.postMessage({type:'nError', error:'func not found'}); return; }
                var result = func(nValue);
                if (result == null) { cipherBridge.postMessage({type:'nError', error:'null result'}); return; }
                cipherBridge.postMessage({type:'nResult', result: String(result)});
            } catch(e) { cipherBridge.postMessage({type:'nError', error: String(e)}); }
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
            cipherBridge.postMessage({type:'initDone', sigOk: sigOk, nOk: nOk});
        }
        </script></head><body><script>
        var js = \(escapeJs(modifiedJs));
        var s = document.createElement('script');
        s.textContent = js;
        document.head.appendChild(s);
        discoverAndInit();
        </script></body></html>
        """

        webView?.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com")!)
    }

    func deobfuscateSignature(_ obfuscatedSig: String) async throws -> String {
        guard sigFunctionAvailable else { throw CipherError.sigNotAvailable }
        let constArgJs = sigInfo.map { $0.constantArg.map(String.init) ?? "null" } ?? "null"
        let js = "deobfuscateSig('\(sigInfo?.name ?? "")', \(constArgJs), '\(escapeJs(obfuscatedSig))')"
        return try await evaluateJS(js, continuationKey: "sig")
    }

    func transformN(_ nValue: String) async throws -> String {
        guard nFunctionAvailable else { throw CipherError.nNotAvailable }
        let js = "transformN('\(escapeJs(nValue))')"
        return try await evaluateJS(js, continuationKey: "n")
    }

    func close() {
        webView?.configuration.userContentController.removeAllUserScripts()
        webView?.loadHTMLString("", baseURL: nil)
        webView = nil
    }

    private func evaluateJS(_ js: String, continuationKey: String) async throws -> String {
        return try await withCheckedThrowingContinuation { cont in
            if continuationKey == "sig" { sigContinuation = cont }
            else { nContinuation = cont }
            webView?.evaluateJavaScript(js)
        }
    }

    private func escapeJs(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "'", with: "\\'")
         .replacingOccurrences(of: "\n", with: "\\n")
         .replacingOccurrences(of: "\r", with: "\\r")
    }

    nonisolated func handleMessage(_ type: String, dict: [String: Any]) {
        Task { @MainActor in
            switch type {
            case "sigResult":
                sigContinuation?(.success(dict["result"] as? String ?? ""))
                sigContinuation = nil
            case "sigError":
                sigContinuation?(.failure(CipherError.sigFailed(dict["error"] as? String ?? "")))
                sigContinuation = nil
            case "nResult":
                nContinuation?(.success(dict["result"] as? String ?? ""))
                nContinuation = nil
            case "nError":
                nContinuation?(.failure(CipherError.nFailed(dict["error"] as? String ?? "")))
                nContinuation = nil
            case "initDone":
                sigFunctionAvailable = dict["sigOk"] as? Bool ?? false
                nFunctionAvailable = dict["nOk"] as? Bool ?? false
                initContinuation?(.success(self))
                initContinuation = nil
            default:
                break
            }
        }
    }
}

extension CipherWebView: WKNavigationDelegate {
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {}
}

class CipherMessageHandler: NSObject, WKScriptMessageHandler {
    let cipher: CipherWebView
    init(cipher: CipherWebView) { self.cipher = cipher }
    nonisolated func userContentController(_ uc: WKUserContentController, didReceive msg: WKScriptMessage) {
        guard let body = msg.body as? [String: Any], let type = body["type"] as? String else { return }
        cipher.handleMessage(type, dict: body)
    }
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
        case .sigFailed(let msg): return "Sig deobfuscation failed: \(msg)"
        case .nFailed(let msg): return "N-transform failed: \(msg)"
        }
    }
}
