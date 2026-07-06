import SwiftUI

struct LikedSongsScreen: View {
    @EnvironmentObject var audioEngine: AudioEngine
    @EnvironmentObject var dataService: SpotifyDataService
    @State private var tracks: [Track] = []

    var body: some View {
        List {
            Section {
                Button(action: {
                    if !tracks.isEmpty { audioEngine.playQueue(tracks) }
                }) {
                    HStack {
                        Spacer()
                        Image(systemName: "play.fill")
                        Text("Play All")
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.green)
            }

            Section {
                ForEach(tracks) { track in
                    SongRow(track: track) {
                        let idx = tracks.firstIndex(where: { $0.id == track.id }) ?? 0
                        audioEngine.playQueue(tracks, startIndex: idx)
                    }
                }
            }
        }
        .navigationTitle("Liked Songs")
        .task {
            tracks = await dataService.likedSongs()
        }
    }
}
