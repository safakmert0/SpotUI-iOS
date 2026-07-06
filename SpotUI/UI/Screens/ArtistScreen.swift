import SwiftUI

struct ArtistScreen: View {
    let name: String
    let id: String
    @EnvironmentObject var audioEngine: AudioEngine
    @EnvironmentObject var dataService: SpotifyDataService
    @State private var overview: ArtistOverview?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header image
                if let url = URL(string: overview?.headerImage ?? "") {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(Color.gray.opacity(0.3))
                    }
                    .frame(height: 200)
                    .clipped()
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(name).font(.title.bold())
                        if overview?.verified == true {
                            Image(systemName: "checkmark.seal.fill").foregroundColor(.blue)
                        }
                    }
                    if let listeners = overview?.monthlyListeners {
                        Text("\(listeners.formatted()) monthly listeners")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)

                // Top tracks
                if let tracks = overview?.topTracks, !tracks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Popular").font(.title3.bold())
                        ForEach(tracks.prefix(5)) { item in
                            SongRow(track: item.song) {
                                let allTracks = tracks.map(\.song)
                                let idx = allTracks.firstIndex(where: { $0.id == item.song.id }) ?? 0
                                audioEngine.playQueue(allTracks, startIndex: idx)
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                // Discography
                if let releases = overview?.popularReleases, !releases.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Discography").font(.title3.bold())
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 16) {
                                ForEach(releases) { album in
                                    AlbumCard(album: album)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            overview = await dataService.artistOverview(artistId: id)
        }
    }
}
