import Foundation

/// Extracts cipher function names from YouTube's player.js.
/// Port of FunctionNameExtractor.kt — uses NSRegularExpression for compatibility.
enum FunctionNameExtractor {

    struct SigFunctionInfo {
        let name: String
        let constantArg: Int?
        let constantArgs: [Int]?
        let preprocessFunc: String?
        let preprocessArgs: [Int]?
        let isHardcoded: Bool
    }

    struct NFunctionInfo {
        let name: String
        let arrayIndex: Int?
        let constantArgs: [Int]?
        let isHardcoded: Bool
    }

    struct PlayerAnalysis {
        let playerHash: String?
        let hasQArrayObfuscation: Bool
        let sigInfo: SigFunctionInfo?
        let nFuncInfo: NFunctionInfo?
        let signatureTimestamp: Int?
    }

    struct HardcodedPlayerConfig {
        let sigFuncName: String
        let sigConstantArg: Int?
        let sigConstantArgs: [Int]?
        let sigPreprocessFunc: String?
        let sigPreprocessArgs: [Int]?
        let nFuncName: String
        let nArrayIndex: Int?
        let nConstantArgs: [Int]?
        let signatureTimestamp: Int
    }

    private static let knownPlayerConfigs: [String: HardcodedPlayerConfig] = [
        "74edf1a3": HardcodedPlayerConfig(
            sigFuncName: "JI", sigConstantArg: 48,
            sigConstantArgs: [48, 1918], sigPreprocessFunc: "f1", sigPreprocessArgs: [1, 6528],
            nFuncName: "GU", nArrayIndex: nil, nConstantArgs: [6, 6010],
            signatureTimestamp: 20522
        )
    ]

    private static func regex(_ pattern: String) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern, options: [])
    }

    private static let qArrayRegex = regex(#"var\s+Q\s*=\s*"[^"]+"\s*\.\s*split\s*\(\s*"\}"\s*\)"#)

    private static let playerHashRegexes = [
        regex(#"jsUrl['":\s]+[^"']*?/player/([a-f0-9]{8})/"#),
        regex(#"player_ias\.vflset/[^/]+/([a-f0-9]{8})/"#),
        regex(#"/s/player/([a-f0-9]{8})/"#),
    ]

    private static let sigFunctionRegexes = [
        regex(#"&&\s*\(\s*[a-zA-Z0-9$]+\s*=\s*([a-zA-Z0-9$]+)\s*\(\s*(\d+)\s*,\s*decodeURIComponent\s*\(\s*[a-zA-Z0-9$]+\s*\)"#),
        regex(#"\b[cs]\s*&&\s*[adf]\.set\([^,]+\s*,\s*encodeURIComponent\(([a-zA-Z0-9$]+)\("#),
        regex(#"\b[a-zA-Z0-9]+\s*&&\s*[a-zA-Z0-9]+\.set\([^,]+\s*,\s*encodeURIComponent\(([a-zA-Z0-9$]+)\("#),
        regex(#"\bm=([a-zA-Z0-9$]{2,})\(decodeURIComponent\(h\.s\)\)"#),
        regex(#"\bc\s*&&\s*d\.set\([^,]+\s*,\s*(?:encodeURIComponent\s*\()([a-zA-Z0-9$]+)\("#),
        regex(#"\bc\s*&&\s*[a-z]\.set\([^,]+\s*,\s*encodeURIComponent\(([a-zA-Z0-9$]+)\("#),
    ]

    private static let nFunctionRegexes = [
        regex(#"\.get\("n"\)\)&&\(b=([a-zA-Z0-9$]+)(?:\[(\d+)\])?\(([a-zA-Z0-9])\)"#),
        regex(#"\.get\("n"\)\)\s*&&\s*\(([a-zA-Z0-9$]+)\s*=\s*([a-zA-Z0-9$]+)(?:\[(\d+)\])?\(\1\)"#),
        regex(#"\(\s*([a-zA-Z0-9$]+)\s*=\s*String\.fromCharCode\(110\)"#),
        regex(#"([a-zA-Z0-9$]+)\s*=\s*function\([a-zA-Z0-9]\)\s*\{[^}]*?enhanced_except_"#),
    ]

    private static func firstMatch(_ text: String, regex: NSRegularExpression) -> NSTextCheckingResult? {
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, options: [], range: range)
    }

    private static func capture(_ result: NSTextCheckingResult, _ text: String, at index: Int) -> String? {
        guard index < result.numberOfRanges else { return nil }
        let r = result.range(at: index)
        guard r.location != NSNotFound, let swiftRange = Range(r, in: text) else { return nil }
        return String(text[swiftRange])
    }

    static func hasQArrayObfuscation(_ playerJs: String) -> Bool {
        firstMatch(playerJs, regex: qArrayRegex) != nil
    }

    static func extractPlayerHash(_ playerJs: String) -> String? {
        for pattern in playerHashRegexes {
            if let result = firstMatch(playerJs, regex: pattern), let hash = capture(result, playerJs, at: 1) {
                return hash
            }
        }
        let content = String(playerJs.prefix(10000))
        guard let data = content.data(using: .utf8) else { return nil }
        return data.map { String(format: "%02x", $0) }.prefix(8).joined()
    }

    static func getHardcodedConfig(_ hash: String) -> HardcodedPlayerConfig? {
        knownPlayerConfigs[hash]
    }

    static func extractSigFunctionInfo(_ playerJs: String, knownHash: String? = nil) -> SigFunctionInfo? {
        for pattern in sigFunctionRegexes {
            if let result = firstMatch(playerJs, regex: pattern),
               let name = capture(result, playerJs, at: 1) {
                let constArg = capture(result, playerJs, at: 2).flatMap(Int.init)
                return SigFunctionInfo(name: name, constantArg: constArg, constantArgs: nil, preprocessFunc: nil, preprocessArgs: nil, isHardcoded: false)
            }
        }
        if hasQArrayObfuscation(playerJs) {
            let hash = knownHash ?? extractPlayerHash(playerJs)
            if let hash, let config = getHardcodedConfig(hash) {
                return SigFunctionInfo(name: config.sigFuncName, constantArg: config.sigConstantArg, constantArgs: config.sigConstantArgs, preprocessFunc: config.sigPreprocessFunc, preprocessArgs: config.sigPreprocessArgs, isHardcoded: true)
            }
        }
        return nil
    }

    static func extractNFunctionInfo(_ playerJs: String, knownHash: String? = nil) -> NFunctionInfo? {
        for (i, pattern) in nFunctionRegexes.enumerated() {
            if let result = firstMatch(playerJs, regex: pattern) {
                switch i {
                case 0:
                    if let name = capture(result, playerJs, at: 1) {
                        let idx = capture(result, playerJs, at: 2).flatMap(Int.init)
                        return NFunctionInfo(name: name, arrayIndex: idx, constantArgs: nil, isHardcoded: false)
                    }
                case 1:
                    if let name = capture(result, playerJs, at: 2) {
                        let idx = capture(result, playerJs, at: 3).flatMap(Int.init)
                        return NFunctionInfo(name: name, arrayIndex: idx, constantArgs: nil, isHardcoded: false)
                    }
                default:
                    if let name = capture(result, playerJs, at: 1) {
                        return NFunctionInfo(name: name, arrayIndex: nil, constantArgs: nil, isHardcoded: false)
                    }
                }
            }
        }
        if hasQArrayObfuscation(playerJs) {
            let hash = knownHash ?? extractPlayerHash(playerJs)
            if let hash, let config = getHardcodedConfig(hash) {
                return NFunctionInfo(name: config.nFuncName, arrayIndex: config.nArrayIndex, constantArgs: config.nConstantArgs, isHardcoded: true)
            }
        }
        return nil
    }

    static func extractSignatureTimestamp(_ playerJs: String) -> Int? {
        let patterns = [
            regex(#"signatureTimestamp['":\s]+(\d+)"#),
            regex(#"sts['":\s]+(\d+)"#),
            regex(#""signatureTimestamp"\s*:\s*(\d+)"#),
        ]
        for pattern in patterns {
            if let result = firstMatch(playerJs, regex: pattern), let ts = capture(result, playerJs, at: 1).flatMap(Int.init) {
                return ts
            }
        }
        if let hash = extractPlayerHash(playerJs), let config = getHardcodedConfig(hash) {
            return config.signatureTimestamp
        }
        return nil
    }

    static func analyzePlayerJs(_ playerJs: String, knownHash: String? = nil) -> PlayerAnalysis {
        let hash = knownHash ?? extractPlayerHash(playerJs)
        return PlayerAnalysis(
            playerHash: hash,
            hasQArrayObfuscation: hasQArrayObfuscation(playerJs),
            sigInfo: extractSigFunctionInfo(playerJs, knownHash: hash),
            nFuncInfo: extractNFunctionInfo(playerJs, knownHash: hash),
            signatureTimestamp: extractSignatureTimestamp(playerJs)
        )
    }
}
