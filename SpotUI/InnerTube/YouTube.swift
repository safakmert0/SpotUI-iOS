import Foundation

/// YouTube search and stream resolution.
/// Port of YouTube.kt — uses InnerTube to search for tracks and resolve streams.
enum YouTube {

    struct SongItem {
        let id: String
        let title: String
        let artists: [ArtistInfo]
        let album: AlbumInfo?
        let duration: Int?
        let isVideoSong: Bool
        let explicit: Bool

        struct ArtistInfo {
            let name: String
        }

        struct AlbumInfo {
            let name: String
        }
    }

    struct SearchResult {
        let items: [SongItem]
    }

    // MARK: - Search

    static func search(_ query: String, filter: SearchFilter = .filterSong) async -> Result<SearchResult, Error> {
        do {
            let response = try await InnerTube.shared.search(query: query, filter: filter.value)
            let items = parseSearchResults(response)
            return .success(SearchResult(items: items))
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Player (stream URL resolution)

    struct PlaybackInfo {
        let streamUrl: String
        let format: AdaptiveFormat
    }

    static func player(videoId: String) async -> Result<PlaybackInfo, Error> {
        do {
            let response = try await InnerTube.shared.player(videoId: videoId)
            guard let streamingData = response.streamingData,
                  let formats = streamingData.adaptiveFormats else {
                return .failure(NSError(domain: "YouTube", code: -1, userInfo: [NSLocalizedDescriptionKey: "No streaming data"]))
            }
            // Pick the best audio-only format (highest bitrate)
            guard let bestAudio = formats
                .filter({ $0.isAudioOnly && $0.url != nil })
                .max(by: { ($0.bitrate ?? 0) < ($1.bitrate ?? 0) }) else {
                return .failure(NSError(domain: "YouTube", code: -1, userInfo: [NSLocalizedDescriptionKey: "No audio format found"]))
            }
            return .success(PlaybackInfo(streamUrl: bestAudio.url!, format: bestAudio))
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Private

    private static func parseSearchResults(_ response: SearchResponse) -> [SongItem] {
        guard let shelves = response.contents?
            .tabbedSearchResultsRenderer?.tabs?.first?
            .tabRenderer?.content?
            .sectionListRenderer?.contents else {
            return []
        }
        return shelves.compactMap { shelf in
            shelf.musicShelfRenderer?.contents?.compactMap { item in
                guard let renderer = item.musicResponsiveListItemRenderer else { return nil }
                let title = extractText(from: renderer.flexColumns?.first)
                let artist = extractText(from: renderer.flexColumns?.dropFirst().first)
                let videoId = renderer.playlistItemData?.playlistReparentingData?.id
                    ?? extractVideoId(from: renderer.flexColumns)
                guard let id = videoId, !title.isEmpty else { return nil }
                return SongItem(
                    id: id,
                    title: title,
                    artists: [SongItem.ArtistInfo(name: artist)],
                    album: nil,
                    duration: nil,
                    isVideoSong: true,
                    explicit: false
                )
            } ?? []
        }.flatMap { $0 }
    }

    private static func extractText(from column: FlexColumn?) -> String {
        column?.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.compactMap(\.text).joined() ?? ""
    }

    private static func extractVideoId(from columns: [FlexColumn]?) -> String? {
        columns?.lazy.compactMap { col -> String? in
            col.musicResponsiveListItemFlexColumnRenderer?.text?.runs?.first?.navigationEndpoint?.watchEndpoint?.videoId
        }.first
    }

    enum SearchFilter {
        case filterSong, filterVideo, filterAlbum, filterArtist, filterPlaylist

        var value: String {
            switch self {
            case .filterSong: return "songs"
            case .filterVideo: return "videos"
            case .filterAlbum: return "albums"
            case .filterArtist: return "artists"
            case .filterPlaylist: return "playlists"
            }
        }
    }
}
