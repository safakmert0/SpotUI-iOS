import SwiftUI

struct HomeScreen: View {
    @EnvironmentObject var audioEngine: AudioEngine
    @EnvironmentObject var dataService: SpotifyDataService
    @State private var greeting = "Good evening"
    @State private var recentlyPlayed: [Track] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Greeting
                Text(greeting)
                    .font(.title.bold())
                    .padding(.horizontal)

                // Quick picks grid (2x3)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                    ForEach(recentlyPlayed.prefix(6)) { track in
                        QuickPickCard(track: track)
                            .onTapGesture {
                                audioEngine.playTrack(track)
                            }
                    }
                }
                .padding(.horizontal)

                // Sections
                ForEach(dataService.homeFeed?.sections ?? []) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title)
                            .font(.title3.bold())
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 16) {
                                ForEach(section.items) { item in
                                    HomeItemCard(item: item)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
    }

    private func loadData() async {
        greeting = await dataService.homeFeed?.greeting ?? "Good evening"
        recentlyPlayed = await dataService.likedSongs().prefix(6).map { $0 }
    }
}

struct QuickPickCard: View {
    let track: Track

    var body: some View {
        HStack(spacing: 0) {
            if let url = URL(string: track.coverUri) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 48, height: 48)
            }
            Text(track.title)
                .font(.subheadline)
                .lineLimit(2)
                .padding(.horizontal, 8)
        }
        .frame(height: 48)
        .background(Color(.systemGray6))
        .cornerRadius(6)
    }
}

struct HomeItemCard: View {
    let item: HomeItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let url = URL(string: item.imageUrl) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 150, height: 150)
                .cornerRadius(4)
            }
            Text(item.name)
                .font(.caption)
                .lineLimit(2)
        }
        .frame(width: 150)
    }
}
