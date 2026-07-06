import SwiftUI

struct SongRow: View {
    let track: Track
    var isActive: Bool = false
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: track.coverUri)) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.3))
                }
                .frame(width: 44, height: 44)
                .cornerRadius(4)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(track.title)
                            .font(.subheadline)
                            .foregroundColor(isActive ? .green : .primary)
                            .lineLimit(1)
                        if track.explicit {
                            Text("E")
                                .font(.caption2.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.gray.opacity(0.6))
                                .cornerRadius(2)
                        }
                    }
                    Text(track.singer)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if track.durationMs > 0 {
                    Text(formatDuration(track.durationMs))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func formatDuration(_ ms: Int) -> String {
        let totalSec = ms / 1000
        let mins = totalSec / 60
        let secs = totalSec % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
