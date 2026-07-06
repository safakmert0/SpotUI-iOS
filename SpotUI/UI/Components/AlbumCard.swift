import SwiftUI

struct AlbumCard: View {
    let album: Album

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let url = URL(string: album.coverUri) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.3))
                }
                .frame(width: 140, height: 140)
                .cornerRadius(4)
            }
            Text(album.name)
                .font(.caption)
                .lineLimit(2)
            Text(album.artists)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(width: 140)
    }
}
