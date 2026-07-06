import SwiftUI

@main
struct SpotUIApp: App {
    @StateObject private var audioEngine = AudioEngine.shared
    @StateObject private var dataService = SpotifyDataService.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(audioEngine)
                .environmentObject(dataService)
                .onAppear {
                    AudioEngine.shared.setupRemoteCommands()
                }
        }
    }
}
