import SwiftUI

struct PlayerScreen: View {
    @EnvironmentObject var audioEngine: AudioEngine
    @State private var showLyrics = false
    @State private var showQueue = false
    @State private var lyrics: Lyrics?
    @State private var sliderValue: Double = 0
    @State private var isDraggingSlider = false

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 8)

            TabView(selection: $showLyrics) {
                // Main player
                mainPlayerView
                    .tag(false)

                // Lyrics
                if let lyrics {
                    LyricsView(lyrics: lyrics, currentTime: audioEngine.currentPosition)
                        .tag(true)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .background(
            Group {
                if let track = audioEngine.currentTrack, let url = URL(string: track.coverUri) {
                    AsyncImage(url: url) { image in
                        image.resizable()
                            .blur(radius: 50)
                            .opacity(0.4)
                            .ignoresSafeArea()
                    } placeholder: {
                        Color.black
                    }
                } else {
                    Color.black
                }
            }
        )
        .task {
            if let track = audioEngine.currentTrack, !track.spotifyTrackId.isEmpty {
                lyrics = await dataService.lyrics(trackId: track.spotifyTrackId)
            }
        }
    }

    @EnvironmentObject var dataService: SpotifyDataService

    private var mainPlayerView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Album art
            if let track = audioEngine.currentTrack, let url = URL(string: track.coverUri) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.3))
                }
                .frame(width: 300, height: 300)
                .cornerRadius(8)
                .shadow(radius: 20)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 300, height: 300)
            }

            // Track info
            VStack(spacing: 4) {
                Text(audioEngine.currentTrack?.title ?? "Not Playing")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(audioEngine.currentTrack?.singer ?? "")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)

                // Source badge
                if !audioEngine.currentSource.isEmpty {
                    Text(audioEngine.currentSource)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal)

            // Slider
            VStack(spacing: 4) {
                Slider(
                    value: $sliderValue,
                    in: 0...(audioEngine.duration > 0 ? audioEngine.duration : 1),
                    onEditingChanged: { editing in
                        isDraggingSlider = editing
                        if !editing {
                            audioEngine.seek(to: sliderValue)
                        }
                    }
                )
                .foregroundColor(.white)

                HStack {
                    Text(formatTime(isDraggingSlider ? sliderValue : audioEngine.currentPosition))
                        .font(.caption).foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text(formatTime(audioEngine.duration))
                        .font(.caption).foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 24)
            .onReceive(audioEngine.$currentPosition) { newValue in
                if !isDraggingSlider {
                    sliderValue = newValue
                }
            }

            // Controls
            HStack(spacing: 40) {
                Button(action: { audioEngine.previous() }) {
                    Image(systemName: "backward.fill").font(.title2).foregroundColor(.white)
                }
                Button(action: { audioEngine.togglePlayPause() }) {
                    Image(systemName: audioEngine.isPlaying ? "pause.fill" : "play.fill")
                        .font(.largeTitle).foregroundColor(.white)
                }
                Button(action: { audioEngine.next() }) {
                    Image(systemName: "forward.fill").font(.title2).foregroundColor(.white)
                }
            }

            // Bottom bar
            HStack {
                Button(action: { showLyrics.toggle() }) {
                    Image(systemName: "text.alignleft").foregroundColor(.white)
                }
                Spacer()
                Button(action: {}) {
                    Image(systemName: "airplayaudio").foregroundColor(.white)
                }
                Spacer()
                NavigationLink(value: Route.queue) {
                    Image(systemName: "list.bullet").foregroundColor(.white)
                }
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

struct LyricsView: View {
    let lyrics: Lyrics
    let currentTime: Double

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(lyrics.lines) { line in
                        Text(line.text)
                            .font(.title2.bold())
                            .foregroundColor(activeLine(line) ? .white : .white.opacity(0.4))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .id(line.id)
                    }
                }
                .padding(.vertical, 50)
            }
            .onChange(of: currentTime) { time in
                if let activeLine = lyrics.lines.last(where: { Double($0.timeMs) / 1000.0 <= time }) {
                    withAnimation {
                        proxy.scrollTo(activeLine.id, anchor: .center)
                    }
                }
            }
        }
    }

    private func activeLine(_ line: LyricLine) -> Bool {
        let timeMs = currentTime * 1000
        return Double(line.timeMs) <= timeMs
    }
}
