import SwiftUI

struct SettingsScreen: View {
    @AppStorage("streamingQuality") private var streamingQuality = "normal"
    @AppStorage("downloadQuality") private var downloadQuality = "high"
    @AppStorage("losslessEnabled") private var losslessEnabled = true
    @AppStorage("losslessHiRes") private var losslessHiRes = true
    @AppStorage("preloadEnabled") private var preloadEnabled = true
    @AppStorage("crossfadeEnabled") private var crossfadeEnabled = false
    @AppStorage("webPlaybackEnabled") private var webPlaybackEnabled = false

    @State private var spDcInput = ""
    @State private var showSpDcAlert = false
    @State private var account: Account?
    @State private var showUpdateAlert = false
    @State private var updateInfo: UpdateChecker.UpdateInfo?

    var body: some View {
        Form {
            Section("Spotify Account") {
                if let account {
                    HStack {
                        AsyncImage(url: URL(string: account.imageUrl)) { img in
                            img.resizable().clipShape(Circle())
                        } placeholder: {
                            Circle().fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 48, height: 48)
                        VStack(alignment: .leading) {
                            Text(account.name).font(.body.bold())
                            Text(account.plan).font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                Button(SpotifySession.shared.isLoggedIn ? "Change sp_dc Cookie" : "Enter sp_dc Cookie") {
                    spDcInput = SpotifySession.shared.spDc
                    showSpDcAlert = true
                }
            }

            Section("Streaming") {
                Picker("Streaming Quality", selection: $streamingQuality) {
                    Text("Low").tag("low")
                    Text("Normal").tag("normal")
                    Text("High").tag("high")
                    Text("Lossless").tag("lossless")
                }
                Toggle("Lossless (SpotiFLAC)", isOn: $losslessEnabled)
                Toggle("Hi-Res (24-bit)", isOn: $losslessHiRes)
                Toggle("Web Playback (Spotify)", isOn: $webPlaybackEnabled)
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
                Button("Check for Updates") {
                    Task {
                        updateInfo = await UpdateChecker.check()
                        if updateInfo != nil { showUpdateAlert = true }
                    }
                }
            }

            Section {
                Button("Log out", role: .destructive) {
                    SpotifySession.shared.clear()
                    SpotifyTokenProvider.shared.invalidateToken()
                    SpotifyRecommendationEngine.invalidateProfile()
                }
            }
        }
        .navigationTitle("Settings")
        .alert("Enter sp_dc Cookie", isPresented: $showSpDcAlert) {
            TextField("sp_dc value", text: $spDcInput)
            Button("Save") {
                guard !spDcInput.isEmpty else { return }
                SpotifySession.shared.spDc = spDcInput
                Task {
                    await SpotifyTokenProvider.shared.refreshToken()
                    account = await SpotifyDataService.shared.accountInfo()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Update Available", isPresented: $showUpdateAlert) {
            Button("Download") {
                if let url = updateInfo.flatMap({ URL(string: $0.downloadUrl) }) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Don't Show Again") {
                if let info = updateInfo { UpdateChecker.skipRelease(info) }
            }
            Button("Later", role: .cancel) {}
        } message: {
            Text("Version \(updateInfo?.version ?? "") is available")
        }
        .task {
            account = await SpotifyDataService.shared.accountInfo()
        }
    }
}
