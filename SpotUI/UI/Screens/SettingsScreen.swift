import SwiftUI

struct SettingsScreen: View {
    @AppStorage("streamingQuality") private var streamingQuality = "normal"
    @AppStorage("downloadQuality") private var downloadQuality = "high"
    @AppStorage("losslessEnabled") private var losslessEnabled = true
    @AppStorage("losslessHiRes") private var losslessHiRes = true
    @AppStorage("preloadEnabled") private var preloadEnabled = true
    @AppStorage("crossfadeEnabled") private var crossfadeEnabled = false

    var body: some View {
        Form {
            Section("Streaming") {
                Picker("Streaming Quality", selection: $streamingQuality) {
                    Text("Low").tag("low")
                    Text("Normal").tag("normal")
                    Text("High").tag("high")
                    Text("Lossless").tag("lossless")
                }
                Toggle("Lossless (SpotiFLAC)", isOn: $losslessEnabled)
                Toggle("Hi-Res (24-bit)", isOn: $losslessHiRes)
            }

            Section("Downloads") {
                Picker("Download Quality", selection: $downloadQuality) {
                    Text("Low").tag("low")
                    Text("Normal").tag("normal")
                    Text("High").tag("high")
                    Text("Lossless").tag("lossless")
                }
            }

            Section("Playback") {
                Toggle("Preload tracks", isOn: $preloadEnabled)
                Toggle("Crossfade", isOn: $crossfadeEnabled)
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0").foregroundColor(.secondary)
                }
            }

            Section {
                Button("Log out", role: .destructive) {
                    SpotifySession.shared.clear()
                }
            }
        }
        .navigationTitle("Settings")
    }
}
