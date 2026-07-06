import SwiftUI

struct HistoryScreen: View {
    @EnvironmentObject var audioEngine: AudioEngine
    @State private var history: [Track] = []

    var body: some View {
        List {
            if history.isEmpty {
                Text("Listening history will appear here")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                Section {
                    Button(action: { if !history.isEmpty { audioEngine.playQueue(history) } }) {
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
                    ForEach(history) { track in
                        SongRow(track: track) {
                            let idx = history.firstIndex(where: { $0.id == track.id }) ?? 0
                            audioEngine.playQueue(history, startIndex: idx)
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
        .task {
            history = ListeningHistory.shared.getHistory()
        }
    }
}

/// Simple listening history persistence using UserDefaults.
enum ListeningHistory {
    static let shared = ListeningHistory()

    private let key = "listening_history"
    private let maxEntries = 200

    func getHistory() -> [Track] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let tracks = try? JSONDecoder().decode([Track].self, from: data) else { return [] }
        return tracks
    }

    func addToHistory(_ track: Track) {
        var tracks = getHistory()
        tracks.removeAll { $0.id == track.id }
        tracks.insert(track, at: 0)
        if tracks.count > maxEntries { tracks = Array(tracks.prefix(maxEntries)) }
        if let data = try? JSONEncoder().encode(tracks) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func clearHistory() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
