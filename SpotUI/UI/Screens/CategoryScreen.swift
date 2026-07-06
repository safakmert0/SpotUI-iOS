import SwiftUI

struct CategoryScreen: View {
    let genre: String
    let title: String

    var body: some View {
        Text("Browse: \(title)")
            .navigationTitle(title)
    }
}
