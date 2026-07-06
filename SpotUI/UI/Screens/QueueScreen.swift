import SwiftUI

struct QueueScreen: View {
    @EnvironmentObject var audioEngine: AudioEngine

    var body: some View {
        List {
            Section("Now Playing") {
                if let track = audioEngine.currentTrack {
                    SongRow(track: track, isActive: true) {}
                }
            }

            Section("Queue") {
                ForEach(Array(audioEngine.queue.enumerated()), id: \.element.id) { index, track in
                    SongRow(track: track, isActive: index == audioEngine.queueIndex) {
                        audioEngine.playQueue(audioEngine.queue, startIndex: index)
                    }
                }
                .onMove { from, to in
                    // Reorder queue
                }
            }
        }
        .navigationTitle("Queue")
        .toolbar {
            EditButton()
        }
    }
}
