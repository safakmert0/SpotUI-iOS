import SwiftUI

/// Root view with tab bar and mini player overlay.
struct RootView: View {
    @State private var selectedTab: Tab = .home
    @State private var showPlayer = false
    @EnvironmentObject var audioEngine: AudioEngine

    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationStack {
                TabView(selection: $selectedTab) {
                    HomeScreen()
                        .tabItem { Label(Tab.home.rawValue, systemImage: Tab.home.icon) }
                        .tag(Tab.home)

                    SearchScreen()
                        .tabItem { Label(Tab.search.rawValue, systemImage: Tab.search.icon) }
                        .tag(Tab.search)

                    LibraryScreen()
                        .tabItem { Label(Tab.library.rawValue, systemImage: Tab.library.icon) }
                        .tag(Tab.library)
                }
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .player: PlayerScreen()
                    case .playlist(let id, let name): PlaylistScreen(playlistId: id, name: name)
                    case .album(let name, let artist): AlbumScreen(name: name, artist: artist)
                    case .artist(let name, let id): ArtistScreen(name: name, id: id)
                    case .queue: QueueScreen()
                    case .liked: LikedSongsScreen()
                    case .downloads: DownloadsScreen()
                    case .history: HistoryScreen()
                    case .settings: SettingsScreen()
                    case .login: LoginScreen()
                    default: EmptyView()
                    }
                }
            }

            // Mini Player
            if audioEngine.currentTrack != nil {
                MiniPlayer(showPlayer: $showPlayer)
                    .padding(.bottom, 50)
            }
        }
        .sheet(isPresented: $showPlayer) {
            PlayerScreen()
                .environmentObject(audioEngine)
        }
    }
}
