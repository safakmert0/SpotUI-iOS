import SwiftUI

struct SearchScreen: View {
    @EnvironmentObject var audioEngine: AudioEngine
    @EnvironmentObject var dataService: SpotifyDataService
    @State private var query = ""
    @State private var results: SearchResults?
    @State private var isSearching = false

    private let categories = [
        ("music.note", "Music", Color.purple),
        ("mic.fill", "Podcasts", Color.green),
        ("book.fill", "Audiobooks", Color.orange),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                if query.isEmpty {
                    // Categories grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                        ForEach(categories, id: \.1) { icon, name, color in
                            CategoryCard(icon: icon, name: name, color: color)
                        }
                    }
                    .padding()
                } else if let results {
                    // Search results
                    VStack(alignment: .leading, spacing: 16) {
                        if !results.songs.isEmpty {
                            SectionHeader(title: "Songs")
                            ForEach(results.songs) { track in
                                SongRow(track: track) {
                                    let idx = results.songs.firstIndex(where: { $0.id == track.id }) ?? 0
                                    audioEngine.playQueue(results.songs, startIndex: idx)
                                }
                            }
                        }
                        if !results.albums.isEmpty {
                            SectionHeader(title: "Albums")
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    ForEach(results.albums) { album in
                                        AlbumCard(album: album)
                                    }
                                }
                            }
                        }
                        if !results.artists.isEmpty {
                            SectionHeader(title: "Artists")
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 16) {
                                    ForEach(results.artists) { artist in
                                        ArtistCard(artist: artist)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                } else if isSearching {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                }
            }
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "What do you want to listen to?")
            .onChange(of: query) { newValue in
                guard !newValue.isEmpty else { results = nil; return }
                Task { await performSearch(newValue) }
            }
        }
    }

    private func performSearch(_ query: String) async {
        isSearching = true
        results = await dataService.search(query: query)
        isSearching = false
    }
}

struct CategoryCard: View {
    let icon: String
    let name: String
    let color: Color

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(height: 100)
            Text(name)
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .padding(12)
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white.opacity(0.8))
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }
}

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title).font(.title2.bold())
    }
}
