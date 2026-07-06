import AVFoundation
import Combine
import MediaPlayer

@MainActor
final class AudioEngine: ObservableObject {
    static let shared = AudioEngine()

    private var player: AVPlayer?
    private var timeObserver: Any?

    @Published var isPlaying = false
    @Published var currentTrack: Track?
    @Published var currentPosition: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var queue: [Track] = []
    @Published var queueIndex: Int = 0
    @Published var currentSource: String = "YouTube"
    @Published var currentQuality: String = ""

    var losslessStreaming = true
    var losslessHiRes = true
    var webPlayerEnabled = false
    var youtubeEnabled = true

    private var streamCache: [String: String] = [:]
    private var sourceCache: [String: String] = [:]
    private var qualityCache: [String: String] = [:]

    private init() {
        setupAudioSession()
    }

    private func setupAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    // MARK: - Controls

    func play() { player?.play(); isPlaying = true }
    func pause() { player?.pause(); isPlaying = false }
    func togglePlayPause() { isPlaying ? pause() : play() }

    func seek(to seconds: TimeInterval) {
        player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        currentPosition = seconds
    }

    func next() {
        guard queueIndex < queue.count - 1 else { queueIndex = 0; if let t = queue.first { playTrack(t) }; return }
        queueIndex += 1
        playTrack(queue[queueIndex])
    }

    func previous() {
        if currentPosition > 3 { seek(to: 0); return }
        guard queueIndex > 0 else { queueIndex = queue.count - 1; playTrack(queue[queueIndex]); return }
        queueIndex -= 1
        playTrack(queue[queueIndex])
    }

    func playTrack(_ track: Track) {
        currentTrack = track
        currentSource = "YouTube"
        currentQuality = ""
        Task { await doPlay(track) }
    }

    private func doPlay(_ track: Track) async {
        guard let streamUrl = await resolveStreamUrl(track), let url = URL(string: streamUrl) else { return }
        let item = AVPlayerItem(url: url)
        if let p = player { p.replaceCurrentItem(with: item) } else { player = AVPlayer(playerItem: item); addTimeObserver() }
        player?.play()
        isPlaying = true
        updateNowPlaying()
    }

    func playQueue(_ songs: [Track], startIndex: Int = 0) {
        queue = songs; queueIndex = startIndex
        if startIndex < songs.count { playTrack(songs[startIndex]) }
    }

    // MARK: - Time observer

    private func addTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.currentPosition = time.seconds.isNaN ? 0 : time.seconds
                if let item = self?.player?.currentItem {
                    let d = item.duration.seconds
                    self?.duration = d.isNaN ? 0 : d
                }
            }
        }
    }

    // MARK: - Stream resolution

    private func resolveStreamUrl(_ track: Track) async -> String? {
        if let cached = streamCache[track.url] { currentSource = sourceCache[track.url] ?? "YouTube"; currentQuality = qualityCache[track.url] ?? ""; return cached }
        if let path = UserPreferences.shared.downloadedPath(for: track.id) { currentSource = "Downloaded"; currentQuality = URL(fileURLWithPath: path).pathExtension.uppercased(); return URL(fileURLWithPath: path).absoluteString }
        if losslessStreaming, !track.spotifyTrackId.isEmpty {
            do {
                let result = try await LosslessResolver.resolve(spotifyTrackId: track.spotifyTrackId, preferHiRes: losslessHiRes)
                currentSource = "Lossless • \(result.provider)"; currentQuality = "FLAC \(result.quality)-bit"
                streamCache[track.url] = result.url; sourceCache[track.url] = currentSource; qualityCache[track.url] = currentQuality
                return result.url
            } catch { print("Lossless miss: \(error)") }
        }
        guard youtubeEnabled else { return nil }
        let searchText = searchTextForPlayback(track.url)
        do {
            let searchResult = try await YouTube.search(searchText).get()
            guard let best = searchResult.items.first else { return nil }
            let playerResult = try await YouTube.player(videoId: best.id).get()
            currentSource = "YouTube"
            let codec = playerResult.format.mimeType?.components(separatedBy: "codecs=\"").last?.components(separatedBy: "\"").first?.components(separatedBy: ".").first?.uppercased() ?? ""
            let bitrate = (playerResult.format.bitrate ?? 0) / 1000
            currentQuality = [codec, "\(bitrate) kbps"].filter { !$0.isEmpty }.joined(separator: " ")
            streamCache[track.url] = playerResult.streamUrl; sourceCache[track.url] = "YouTube"; qualityCache[track.url] = currentQuality
            return playerResult.streamUrl
        } catch { print("YouTube resolve failed: \(error)"); return nil }
    }

    private func searchTextForPlayback(_ query: String) -> String {
        if query.hasPrefix("spotify:track:"), let i = query.firstIndex(of: "|") { return String(query[query.index(after: i)...]) }
        return query
    }

    // MARK: - Now Playing

    private func updateNowPlaying() {
        guard let track = currentTrack else { return }
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = track.title
        info[MPMediaItemPropertyArtist] = track.singer
        info[MPMediaItemPropertyAlbumTitle] = track.album
        info[MPMediaItemPropertyPlaybackDuration] = NSNumber(value: duration)
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = NSNumber(value: currentPosition)
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in self?.play(); return .success }
        center.pauseCommand.addTarget { [weak self] _ in self?.pause(); return .success }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in self?.togglePlayPause(); return .success }
        center.nextTrackCommand.addTarget { [weak self] _ in self?.next(); return .success }
        center.previousTrackCommand.addTarget { [weak self] _ in self?.previous(); return .success }
    }

    // MARK: - Downloads

    func downloadTrack(_ track: Track) async -> Bool {
        guard let streamUrl = await resolveStreamUrl(track), let url = URL(string: streamUrl) else { return false }
        let dir = UserPreferences.shared.downloadsDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let outFile = dir.appendingPathComponent("\(track.id).m4a")
        do {
            let (tempURL, _) = try await URLSession.shared.download(for: URLRequest(url: url))
            try FileManager.default.moveItem(at: tempURL, to: outFile)
            return true
        } catch { return false }
    }
}

// MARK: - Free functions (outside @MainActor)

func buildPlayQuery(spotifyTrackId: String, title: String, artist: String) -> String {
    let cleaned = title.replacingOccurrences(of: #"\s*[\(\[]\s*(feat|ft)\..*?[\)\]]"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
    let searchText = [cleaned, artist].filter { !$0.isEmpty }.joined(separator: " ")
    if spotifyTrackId.isEmpty { return searchText }
    return "spotify:track:\(spotifyTrackId)|\(searchText)"
}
