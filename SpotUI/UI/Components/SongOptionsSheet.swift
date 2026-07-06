import SwiftUI

struct SongOptionsSheet: View {
    let track: Track
    @EnvironmentObject var audioEngine: AudioEngine
    @EnvironmentObject var dataService: SpotifyDataService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section {
                    Button(action: {
                        Task { await dataService.likeTrack(track) }
                        dismiss()
                    }) {
                        Label("Add to Liked Songs", systemImage: "heart")
                    }
                }

                Section {
                    Button(action: {
                        Task { await dataService.unlikeTrack(track) }
                        dismiss()
                    }) {
                        Label("Remove from Liked Songs", systemImage: "heart.slash")
                    }
                }

                Section {
                    Button(action: {
                        Task {
                            let success = await audioEngine.downloadTrack(track)
                            print("Download \(success ? "succeeded" : "failed")")
                        }
                        dismiss()
                    }) {
                        Label("Download", systemImage: "arrow.down.circle")
                    }
                }
            }
            .navigationTitle(track.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
