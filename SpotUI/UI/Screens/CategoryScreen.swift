import SwiftUI

struct CategoryScreen: View {
    let genre: String
    let title: String
    @EnvironmentObject var audioEngine: AudioEngine
    @State private var playlists: [LibraryEntry] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if playlists.isEmpty {
                Text("No playlists found")
                    .foregroundColor(.secondary)
            } else {
                List {
                    ForEach(playlists) { entry in
                        NavigationLink(value: Route.playlist(id: entry.spotifyId, name: entry.name)) {
                            HStack {
                                AsyncImage(url: URL(string: entry.coverUri)) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.3))
                                }
                                .frame(width: 56, height: 56)
                                .cornerRadius(4)

                                VStack(alignment: .leading) {
                                    Text(entry.name).font(.body)
                                    Text(entry.subtitle).font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
        .task {
            await loadPlaylists()
        }
    }

    private func loadPlaylists() async {
        guard await SpotifyTokenProvider.shared.ensureToken() else { isLoading = false; return }
        let result: SpotifySearchResult? = try? await SpotifyAPI.search(query: genre, types: "playlist", limit: 24)
        playlists = result?.playlists?.items.map { p in
            LibraryEntry(
                spotifyId: p.id,
                name: p.name,
                subtitle: "Playlist" + ((p.owner?.displayName).map { " \u{2022} \($0)" } ?? ""),
                coverUri: p.images.first?.url ?? "",
                isPlaylist: true,
                artists: ""
            )
        } ?? []
        isLoading = false
    }
}
