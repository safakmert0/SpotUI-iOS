import Foundation
import CryptoKit

/// Extracts cipher function names from YouTube's player.js.
/// Port of FunctionNameExtractor.kt — handles regex patterns and hardcoded configs.
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

    private static let qArrayPattern = /var\s+Q\s*=\s*"[^"]+"\s*\.\s*split\s*\(\s*"\}"\s*\)/

    private static let playerHashPatterns: [Regex] = [
        /jsUrl['":\s]+[^"']*?\/player\/([a-f0-9]{8})\//,
        /player_ias\.vflset\/[^/]+\/([a-f0-9]{8})\//,
        /\/s\/player\/([a-f0-9]{8})\//
    ]

    private static let sigFunctionPatterns: [Regex] = [
        /&&\s*\(\s*[a-zA-Z0-9$]+\s*=\s*([a-zA-Z0-9$]+)\s*\(\s*(\d+)\s*,\s*decodeURIComponent\s*\(\s*[a-zA-Z0-9$]+\s*\)/,
        /\b[cs]\s*&&\s*[adf]\.set\([^,]+\s*,\s*encodeURIComponent\(([a-zA-Z0-9$]+)\(/,
        /\b[a-zA-Z0-9]+\s*&&\s*[a-zA-Z0-9]+\.set\([^,]+\s*,\s*encodeURIComponent\(([a-zA-Z0-9$]+)\(/,
        /\bm=([a-zA-Z0-9$]{2,})\(decodeURIComponent\(h\.s\)\)/,
        /\bc\s*&&\s*d\.set\([^,]+\s*,\s*(?:encodeURIComponent\s*\()([a-zA-Z0-9$]+)\(/,
        /\bc\s*&&\s*[a-z]\.set\([^,]+\s*,\s*encodeURIComponent\(([a-zA-Z0-9$]+)\(/
    ]

    private static let nFunctionPatterns: [Regex] = [
        /\.get\("n"\)\)&&\(b=([a-zA-Z0-9$]+)(?:\[(\d+)\])?\(([a-zA-Z0-9])\)/,
        /\.get\("n"\)\)\s*&&\s*\(([a-zA-Z0-9$]+)\s*=\s*([a-zA-Z0-9$]+)(?:\[(\d+)\])?\(\1\)/,
        /\(\s*([a-zA-Z0-9$]+)\s*=\s*String\.fromCharCode\(110\)/,
        /([a-zA-Z0-9$]+)\s*=\s*function\([a-zA-Z0-9]\)\s*\{[^}]*?enhanced_except_/
    ]

    static func hasQArrayObfuscation(_ playerJs: String) -> Bool {
        playerJs.contains(qArrayPattern)
    }

    static func extractPlayerHash(_ playerJs: String) -> String? {
        for pattern in playerHashPatterns {
            if let match = playerJs.firstMatch(of: pattern) {
                return String(match.1)
            }
        }
        let content = String(playerJs.prefix(10000))
        let digest = Insecure.MD5.hash(data: content.data(using: .utf8)!)
        return digest.prefix(4).map { String(format: "%02x", $0) }.joined()
    }

    static func getHardcodedConfig(_ hash: String) -> HardcodedPlayerConfig? {
        knownPlayerConfigs[hash]
    }

    static func extractSigFunctionInfo(_ playerJs: String, knownHash: String? = nil) -> SigFunctionInfo? {
        for pattern in sigFunctionPatterns {
            if let match = playerJs.firstMatch(of: pattern) {
                let name = String(match.1)
                let constArg = match.output.count > 2 ? Int(String(match.2)) : nil
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
        for (i, pattern) in nFunctionPatterns.enumerated() {
            if let match = playerJs.firstMatch(of: pattern) {
                switch i {
                case 0:
                    return NFunctionInfo(name: String(match.1), arrayIndex: Int(String(match.2)), constantArgs: nil, isHardcoded: false)
                case 1:
                    return NFunctionInfo(name: String(match.2), arrayIndex: Int(String(match.3)), constantArgs: nil, isHardcoded: false)
                default:
                    return NFunctionInfo(name: String(match.1), arrayIndex: nil, constantArgs: nil, isHardcoded: false)
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
        let patterns = [/signatureTimestamp['":\s]+(\d+)/, /sts['":\s]+(\d+)/, /"signatureTimestamp"\s*:\s*(\d+)/]
        for pattern in patterns {
            if let match = playerJs.firstMatch(of: pattern), let ts = Int(String(match.1)) {
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
