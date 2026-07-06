import SwiftUI

struct ShowScreen: View {
    let showId: String
    let name: String

    var body: some View {
        Text("Podcast: \(name)")
            .navigationTitle(name)
    }
}
