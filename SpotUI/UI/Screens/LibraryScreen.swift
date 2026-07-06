import SwiftUI

struct LibraryScreen: View {
    @EnvironmentObject var audioEngine: AudioEngine
    @EnvironmentObject var dataService: SpotifyDataService
    @State private var entries: [LibraryEntry] = []
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List {
                // Quick links
                Section {
                    NavigationLink(value: Route.liked) {
                        Label("Liked Songs", systemImage: "heart.fill")
                            .foregroundColor(.green)
                    }
                    NavigationLink(value: Route.downloads) {
                        Label("Downloads", systemImage: "arrow.down.circle.fill")
                    }
                    NavigationLink(value: Route.history) {
                        Label("History", systemImage: "clock.fill")
                    }
                }

                // Playlists
                Section("Playlists") {
                    ForEach(filteredEntries.filter(\.isPlaylist)) { entry in
                        NavigationLink(value: Route.playlist(id: entry.spotifyId, name: entry.name)) {
                            HStack {
                                AsyncImage(url: URL(string: entry.coverUri)) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.3))
                                }
                                .frame(width: 48, height: 48)

                                VStack(alignment: .leading) {
                                    Text(entry.name).font(.body)
                                    Text(entry.subtitle).font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                // Albums
                Section("Albums") {
                    ForEach(filteredEntries.filter { !$0.isPlaylist }) { entry in
                        NavigationLink(value: Route.album(name: entry.name, artist: entry.artists)) {
                            HStack {
                                AsyncImage(url: URL(string: entry.coverUri)) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.3))
                                }
                                .frame(width: 48, height: 48)

                                VStack(alignment: .leading) {
                                    Text(entry.name).font(.body)
                                    Text(entry.artists).font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Your Library")
            .searchable(text: $searchText)
            .task {
                entries = await dataService.library()
            }
        }
    }

    private var filteredEntries: [LibraryEntry] {
        guard !searchText.isEmpty else { return entries }
        return entries.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.subtitle.localizedCaseInsensitiveContains(searchText)
        }
    }
}
