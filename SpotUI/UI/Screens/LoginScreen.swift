import SwiftUI
import AuthenticationServices

struct LoginScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var spDcInput = ""
    @State private var showManualInput = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "music.note")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("SpotUI")
                .font(.largeTitle.bold())

            Text("Sign in with your Spotify account")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button(action: { showManualInput = true }) {
                HStack {
                    Spacer()
                    Text("Enter sp_dc cookie")
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding()
                .background(Color.green)
                .cornerRadius(8)
            }

            Text("Get sp_dc from open.spotify.com → DevTools → Application → Cookies")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
        .padding()
        .alert("Enter sp_dc Cookie", isPresented: $showManualInput) {
            TextField("sp_dc value", text: $spDcInput)
            Button("Save") {
                guard !spDcInput.isEmpty else { return }
                SpotifySession.shared.spDc = spDcInput
                Task {
                    await SpotifyTokenProvider.shared.refreshToken()
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
