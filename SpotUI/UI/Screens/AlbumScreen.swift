import SwiftUI

struct AlbumScreen: View {
    let name: String
    let artist: String
    @EnvironmentObject var audioEngine: AudioEngine
    @State private var tracks: [Track] = []

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Text(name).font(.title2.bold())
                    Text(artist).font(.subheadline).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }

            Section {
                Button(action: {
                    if !tracks.isEmpty { audioEngine.playQueue(tracks) }
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
            tracks = await dataService.albumSongs(name: name, artist: artist)
        }
    }
}
