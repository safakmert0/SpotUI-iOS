import SwiftUI

struct DownloadsScreen: View {
    @EnvironmentObject var audioEngine: AudioEngine
    @State private var tracks: [Track] = []

    var body: some View {
        List {
            if tracks.isEmpty {
                Text("No downloads yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                Section {
                    Button(action: { if !tracks.isEmpty { audioEngine.playQueue(tracks) } }) {
                        HStack {
                            Spacer()
                            Image(systemName: "play.fill")
                            Text("Play All")
                            Spacer()
                        }
                        .foregroundColor(.white)
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
        }
        .navigationTitle("Downloads")
    }
}
