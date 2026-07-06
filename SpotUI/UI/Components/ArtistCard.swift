import SwiftUI

struct ArtistCard: View {
    let artist: Artist

    var body: some View {
        VStack(spacing: 4) {
            if let url = URL(string: artist.coverUri) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle().fill(Color.gray.opacity(0.3))
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 120, height: 120)
            }
            Text(artist.name)
                .font(.caption)
                .lineLimit(1)
        }
        .frame(width: 120)
    }
}
