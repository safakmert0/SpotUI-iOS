import Foundation

/// Fetches Spotify Canvas — looping videos on the now-playing screen.
/// Port of SpotifyCanvas.kt — uses protobuf wire format for request/response.
enum SpotifyCanvas {
    private static let endpoint = "https://spclient.wg.spotify.com/canvaz-cache/v0/canvases"
    private static let client = HTTPClient.shared

    /// Returns the canvas video URL for a track, or nil if unavailable.
    static func canvasUrl(trackId: String, accessToken: String) async -> String? {
        guard !trackId.isEmpty, !accessToken.isEmpty else { return nil }
        let uri = "spotify:track:\(trackId)"
        let body = encodeRequest(uri: uri)

        guard let data = try? await client.getData(
            endpoint,
            headers: [
                "Authorization": "Bearer \(accessToken)",
                "Accept": "application/protobuf",
            ]
        ) else { return nil }

        // Hand-decode the protobuf response: EntityCanvazResponse → first Canvaz → url (field 2)
        return decodeFirstUrl(from: data)
    }

    // MARK: - Protobuf wire encode

    private static func encodeRequest(uri: String) -> Data {
        let uriBytes = Array(uri.utf8)
        // Entity: field 1 (entity_uri), wire type 2 (length-delimited)
        var entity = Data()
        writeTag(&entity, field: 1, wire: 2)
        writeVarint(&entity, value: UInt64(uriBytes.count))
        entity.append(contentsOf: uriBytes)
        // EntityCanvazRequest: field 1 (entities), wire type 2
        var request = Data()
        writeTag(&request, field: 1, wire: 2)
        writeVarint(&request, value: UInt64(entity.count))
        request.append(entity)
        return request
    }

    // MARK: - Protobuf wire decode

    private static func decodeFirstUrl(from data: Data) -> String? {
        var pos = 0
        while pos < data.count {
            var field: Int = 0
            var wire: Int = 0
            (field, wire, pos) = readTag(from: data, at: pos)
            if field == 1 && wire == 2 {
                let (bytes, newPos) = readBytes(from: data, at: pos)
                pos = newPos
                if let url = decodeCanvazUrl(from: bytes) { return url }
            } else {
                pos = skipField(from: data, at: pos, wireType: wire)
            }
        }
        return nil
    }

    private static func decodeCanvazUrl(from data: Data) -> String? {
        var pos = 0
        while pos < data.count {
            var field: Int = 0
            var wire: Int = 0
            (field, wire, pos) = readTag(from: data, at: pos)
            if field == 2 && wire == 2 {
                let (bytes, _) = readBytes(from: data, at: pos)
                return String(data: bytes, encoding: .utf8)
            }
            pos = skipField(from: data, at: pos, wireType: wire)
        }
        return nil
    }

    // MARK: - Wire helpers

    private static func writeTag(_ data: inout Data, field: Int, wire: Int) {
        writeVarint(&data, value: UInt64((field << 3) | wire))
    }

    private static func writeVarint(_ data: inout Data, value: UInt64) {
        var v = value
        while true {
            let bits = Int(v & 0x7F)
            v >>= 7
            if v != 0 {
                data.append(UInt8(bits | 0x80))
            } else {
                data.append(UInt8(bits))
                break
            }
        }
    }

    private static func readTag(from data: Data, at start: Int) -> (field: Int, wire: Int, nextPos: Int) {
        let (value, pos) = readVarint(from: data, at: start)
        return (Int(value >> 3), Int(value & 7), pos)
    }

    private static func readVarint(from data: Data, at start: Int) -> (UInt64, Int) {
        var result: UInt64 = 0
        var shift = 0
        var pos = start
        while pos < data.count {
            let byte = data[pos]
            pos += 1
            result |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 { break }
            shift += 7
        }
        return (result, pos)
    }

    private static func readBytes(from data: Data, at start: Int) -> (Data, Int) {
        let (length, pos) = readVarint(from: data, at: start)
        let end = min(pos + Int(length), data.count)
        return (data.subdata(in: pos..<end), end)
    }

    private static func skipField(from data: Data, at pos: Int, wireType: Int) -> Int {
        switch wireType {
        case 0:
            let (_, newPos) = readVarint(from: data, at: pos)
            return newPos
        case 1:
            return pos + 8
        case 2:
            let (_, newPos) = readVarint(from: data, at: pos)
            let (bytes, endPos) = readBytes(from: data, at: newPos)
            return endPos
        case 5:
            return pos + 4
        default:
            return data.count
        }
    }
}
