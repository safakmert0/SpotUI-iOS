import SwiftUI

struct MiniPlayer: View {
    @Binding var showPlayer: Bool
    @EnvironmentObject var audioEngine: AudioEngine

    var body: some View {
        if let track = audioEngine.currentTrack {
            VStack(spacing: 0) {
                // Progress bar
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: geo.size.width * progressFraction, height: 2)
                }
                .frame(height: 2)

                HStack(spacing: 12) {
                    // Artwork
                    AsyncImage(url: URL(string: track.coverUri)) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 40, height: 40)
                    .cornerRadius(4)

                    // Info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.subheadline)
                            .lineLimit(1)
                        Text(track.singer)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Source badge
                    if !audioEngine.currentSource.isEmpty {
                        Text(audioEngine.currentSource)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // Controls
                    Button(action: { audioEngine.togglePlayPause() }) {
                        Image(systemName: audioEngine.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                    }

                    Button(action: { audioEngine.next() }) {
                        Image(systemName: "forward.fill")
                            .font(.body)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
            }
            .onTapGesture {
                showPlayer = true
            }
        }
    }

    private var progressFraction: CGFloat {
        guard audioEngine.duration > 0 else { return 0 }
        return CGFloat(audioEngine.currentPosition / audioEngine.duration)
    }
}
