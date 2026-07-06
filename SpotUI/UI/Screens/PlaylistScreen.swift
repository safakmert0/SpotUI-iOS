import SwiftUI

struct PlaylistScreen: View {
    let playlistId: String
    let name: String
    @EnvironmentObject var audioEngine: AudioEngine
    @EnvironmentObject var dataService: SpotifyDataService
    @State private var tracks: [Track] = []
    @State private var playlist: SpotifyPlaylist?

    var body: some View {
        List {
            // Header
            if let playlist {
                Section {
                    VStack(spacing: 12) {
                        if let urlStr = SpotifyMapper.playlistThumbnail(playlist),
                           let url = URL(string: urlStr) {
                            AsyncImage(url: url) { image in
                                image.resizable().aspectRatio(contentMode: .fit)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.3))
                            }
                            .frame(width: 200, height: 200)
                            .cornerRadius(4)
                        }
                        Text(playlist.name).font(.title2.bold())
                        if let desc = playlist.description {
                            Text(desc).font(.caption).foregroundColor(.secondary)
                        }
                        Text("\(playlist.tracks?.total ?? 0) songs")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }

                // Play button
                Section {
                    Button(action: {
                        if !tracks.isEmpty {
                            audioEngine.playQueue(tracks)
                        }
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "play.fill")
                            Text("Play")
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(Color.green)
                }
            }

            // Tracks
            Section {
                ForEach(tracks) { track in
                    SongRow(track: track) {
                        let idx = tracks.firstIndex(where: { $0.id == track.id }) ?? 0
                        audioEngine.playQueue(tracks, startIndex: idx)
                    }
                }
            }
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            playlist = try? await SpotifyAPI.playlist(playlistId)
            tracks = await dataService.playlistSongs(playlistId: playlistId)
        }
    }
}
