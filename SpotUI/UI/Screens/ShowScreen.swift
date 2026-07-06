import SwiftUI

struct ShowScreen: View {
    let showId: String
    let name: String
    @EnvironmentObject var audioEngine: AudioEngine
    @State private var episodes: [Track] = []
    @State private var show: SpotifyShow?
    @State private var isLoading = true

    var body: some View {
        List {
            if let show {
                Section {
                    VStack(spacing: 12) {
                        if let url = URL(string: show.images.first?.url ?? "") {
                            AsyncImage(url: url) { image in
                                image.resizable().aspectRatio(contentMode: .fit)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 160, height: 160)
                            .cornerRadius(8)
                        }
                        Text(show.name).font(.title2.bold())
                        Text(show.publisher).font(.caption).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
            }

            if !episodes.isEmpty {
                Section("Episodes") {
                    ForEach(episodes) { episode in
                        SongRow(track: episode) {
                            let idx = episodes.firstIndex(where: { $0.id == episode.id }) ?? 0
                            audioEngine.playQueue(episodes, startIndex: idx)
                        }
                    }
                }
            }
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
    }

    private func loadData() async {
        guard await SpotifyTokenProvider.shared.ensureToken() else { isLoading = false; return }
        show = try? await SpotifyAPI.show(showId)
        let episodesResult: SpotifyPaging<SpotifyEpisode>? = try? await SpotifyAPI.showEpisodes(showId: showId)
        episodes = episodesResult?.items.map { ep in
            Track(
                id: ep.name.hashValue & 0x7FFFFFFF,
                title: ep.name,
                album: show?.name ?? "Podcast",
                singer: show?.name ?? "Podcast",
                coverUri: ep.images.first?.url ?? show?.images.first?.url ?? "",
                url: "episode:\(ep.id)",
                spotifyTrackId: "",
                explicit: false,
                durationMs: ep.durationMs
            )
        } ?? []
        isLoading = false
    }
}
