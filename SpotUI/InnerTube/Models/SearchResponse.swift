import Foundation

struct SearchResponse: Codable {
    let contents: SearchContents?
}

struct SearchContents: Codable {
    let tabbedSearchResultsRenderer: TabbedSearchResults?
}

struct TabbedSearchResults: Codable {
    let tabs: [YTTab]?
}

struct YTTab: Codable {
    let tabRenderer: TabRenderer?
}

struct TabRenderer: Codable {
    let content: TabContent?
}

struct TabContent: Codable {
    let sectionListRenderer: SectionListRenderer?
}

struct SectionListRenderer: Codable {
    let contents: [SectionContent]?
}

struct SectionContent: Codable {
    let musicShelfRenderer: MusicShelf?
}

struct MusicShelf: Codable {
    let contents: [MusicShelfContent]?
    let continuations: [Continuation]?
}

struct MusicShelfContent: Codable {
    let musicResponsiveListItemRenderer: MusicResponsiveListItem?
}

struct MusicResponsiveListItem: Codable {
    let flexColumns: [FlexColumn]?
    let thumbnail: ThumbnailContainer?
    let playlistItemData: PlaylistItemData?
}

struct FlexColumn: Codable {
    let musicResponsiveListItemFlexColumnRenderer: FlexColumnRenderer?
}

struct FlexColumnRenderer: Codable {
    let text: TextObject?
}

struct TextObject: Codable {
    let runs: [Run]?
}

struct Run: Codable {
    let text: String?
    let navigationEndpoint: NavigationEndpoint?
}

struct NavigationEndpoint: Codable {
    let watchEndpoint: WatchEndpoint?
    let browseEndpoint: BrowseEndpoint?
}

struct WatchEndpoint: Codable {
    let videoId: String?
}

struct BrowseEndpoint: Codable {
    let browseId: String?
}

struct ThumbnailContainer: Codable {
    let musicThumbnailRenderer: MusicThumbnail?
}

struct MusicThumbnail: Codable {
    let thumbnails: [Thumbnail]?
}

struct Thumbnail: Codable {
    let url: String?
    let width: Int?
    let height: Int?
}

struct PlaylistItemData: Codable {
    let playlistReparentingData: PlaylistReparentingData?
}

struct PlaylistReparentingData: Codable {
    let id: String?
}

struct Continuation: Codable {
    let continuation: String?
}
