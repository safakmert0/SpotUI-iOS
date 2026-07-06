import SwiftUI

struct HistoryScreen: View {
    var body: some View {
        List {
            Text("Listening history will appear here")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding()
        }
        .navigationTitle("History")
    }
}
