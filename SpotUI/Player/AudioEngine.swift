import AVFoundation
import Combine

/// Main audio playback engine. Port of SongPlayer.kt + PlaybackService.kt.
/// Manages AVPlayer, stream resolution, queue, crossfade, downloads.
@MainActor
final class AudioEngine: ObservableObject {
    static let shared = AudioEngine()

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published state

    @Published var isPlaying = false
    @Published var currentTrack: Track?
    @Published var currentPosition: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var queue: [Track] = []
    @Published var queueIndex: Int = 0
    @Published var currentSource: String = "YouTube"
    @Published var currentQuality: String = ""
    @Published var volume: Float = 1.0

    // MARK: - Source engine flags

    var losslessStreaming = true
    var losslessHiRes = true
    var webPlayerEnabled = false
    var youtubeEnabled = true

    // MARK: - Caches

    private var streamCache: [String: String] = [:]
    private var sourceCache: [String: String] = [:]
    private var qualityCache: [String: String] = [:]
    private var trackIdRegistry: [String: String] = [:]
    private var explicitRegistry: [String: Bool] = [:]
    private var durationRegistry: [String: Int] = [:]
    private var metadataRegistry: [String: TrackMatchMetadata] = [:]

    struct TrackMatchMetadata {
        let title: String
        let artist: String
        let album: String
    }

    private init() {
        setupAudioSession()
        setupTimeObserver()
    }

    // MARK: - Audio Session

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AudioEngine: Failed to set up audio session — \(error)")
        }
    }

    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            Task { @MainActor in
                self.currentPosition = time.seconds.isNaN ? 0 : time.seconds
                if let item = self.player?.currentItem {
                    let dur = item.duration.seconds
                    self.duration = dur.isNaN ? 0 : dur
                }
            }
        }
    }

    // MARK: - Playback controls

    func play() {
        player?.play()
        isPlaying = true
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func togglePlayPause() {
        if isPlaying { pause() } else { play() }
    }

    func seek(to seconds: TimeInterval) {
        let cmTime = CMTime(seconds: seconds, preferredTimescale: 600)
        player?.seek(to: cmTime)
        currentPosition = seconds
    }

    func seekForward(_ seconds: Double = 15) {
        seek(to: min(currentPosition + seconds, duration))
    }

    func seekBackward(_ seconds: Double = 15) {
        seek(to: max(currentPosition - seconds, 0))
    }

    func next() {
        guard queueIndex < queue.count - 1 else {
            queueIndex = 0
            if let track = queue.first { playTrack(track) }
            return
        }
        queueIndex += 1
        playTrack(queue[queueIndex])
    }

    func previous() {
        if currentPosition > 3 {
            seek(to: 0)
            return
        }
        guard queueIndex > 0 else {
            queueIndex = queue.count - 1
            playTrack(queue[queueIndex])
            return
        }
        queueIndex -= 1
        playTrack(queue[queueIndex])
    }

    // MARK: - Play track

    func playTrack(_ track: Track) {
        currentTrack = track
        currentSource = "YouTube"
        currentQuality = ""

        Task {
            guard let streamUrl = await resolveStreamUrl(track) else {
                print("AudioEngine: Could not resolve stream for \(track.title)")
                return
            }
            guard let url = URL(string: streamUrl) else { return }

            let playerItem = AVPlayerItem(url: url)
            let metadata = AVMutableMetadataItem()
            metadata.keySpace = .common
            metadata.key = AVMetadataKey.commonKeyTitle as NSString
            metadata.value = track.title as NSString
            playerItem.externalMetadata.append(metadata)

            let artistMeta = AVMutableMetadataItem()
            artistMeta.keySpace = .common
            artistMeta.key = AVMetadataKey.commonKeyArtist as NSString
            artistMeta.value = track.singer as NSString
            playerItem.externalMetadata.append(artistMeta)

            if !track.coverUri.isEmpty, let coverURL = URL(string: track.coverUri) {
                if let data = try? Data(contentsOf: coverURL),
                   let image = UIImage(data: data) {
                    let artMeta = AVMutableMetadataItem()
                    artMeta.keySpace = .common
                    artMeta.key = AVMetadataKey.commonKeyArtwork as NSString
                    artMeta.value = image.pngData() as NSData?
                    playerItem.externalMetadata.append(artMeta)
                }
            }

            if let player {
                player.replaceCurrentItem(with: playerItem)
            } else {
                player = AVPlayer(playerItem: playerItem)
                setupTimeObserver()
            }
            player?.play()
            isPlaying = true

            updateNowPlaying()
        }
    }

    func playQueue(_ songs: [Track], startIndex: Int = 0) {
        queue = songs
        queueIndex = startIndex
        if startIndex < songs.count {
            playTrack(songs[startIndex])
        }
    }

    func setQueue(_ songs: [Track]) {
        queue = songs
    }

    // MARK: - Build play query

    nonisolated static func buildPlayQuery(spotifyTrackId: String, title: String, artist: String) -> String {
        let searchText = [cleanTitle(title), artist].filter { !$0.isEmpty }.joined(separator: " ")
        if spotifyTrackId.isEmpty { return searchText }
        return "spotify:track:\(spotifyTrackId)|\(searchText)"
    }

    private nonisolated static func cleanTitle(_ title: String) -> String {
        let pattern = try! NSRegularExpression(pattern: "\\s*[\\(\\[]\\s*(feat|ft)\\..*?[\\)\\]]", options: .caseInsensitive)
        let range = NSRange(title.startIndex..., in: title)
        return pattern.stringByReplacingMatches(in: title, options: [], range: range, withTemplate: "").trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Stream resolution

    private func resolveStreamUrl(_ track: Track) async -> String? {
        // 1. Check cache
        if let cached = streamCache[track.url] {
            currentSource = sourceCache[track.url] ?? "YouTube"
            currentQuality = qualityCache[track.url] ?? ""
            return cached
        }

        // 2. Check downloads
        if let path = UserPreferences.shared.downloadedPath(for: track.id) {
            currentSource = "Downloaded"
            currentQuality = URL(fileURLWithPath: path).pathExtension.uppercased()
            return URL(fileURLWithPath: path).absoluteString
        }

        // 3. Try lossless (SpotiFLAC)
        if losslessStreaming, !track.spotifyTrackId.isEmpty {
            do {
                let result = try await LosslessResolver.resolve(
                    spotifyTrackId: track.spotifyTrackId,
                    preferHiRes: losslessHiRes
                )
                currentSource = "Lossless • \(result.provider)"
                currentQuality = "FLAC \(result.quality)-bit"
                streamCache[track.url] = result.url
                sourceCache[track.url] = currentSource
                qualityCache[track.url] = currentQuality
                return result.url
            } catch {
                print("AudioEngine: SpotiFLAC miss — \(error)")
            }
        }

        // 4. YouTube fallback
        guard youtubeEnabled else { return nil }
        let searchText = searchTextForPlayback(track.url)
        do {
            let searchResult = try await YouTube.search(searchText).get()
            guard let bestItem = searchResult.items.first else { return nil }
            let playerResult = try await YouTube.player(videoId: bestItem.id).get()
            currentSource = "YouTube"
            let codec = playerResult.format.mimeType?
                .components(separatedBy: "codecs=\"").last?
                .components(separatedBy: "\"").first?
                .components(separatedBy: ".").first?.uppercased() ?? ""
            let bitrate = (playerResult.format.bitrate ?? 0) / 1000
            currentQuality = [codec, "\(bitrate) kbps"].filter { !$0.isEmpty }.joined(separator: " ")
            streamCache[track.url] = playerResult.streamUrl
            sourceCache[track.url] = "YouTube"
            qualityCache[track.url] = currentQuality
            return playerResult.streamUrl
        } catch {
            print("AudioEngine: YouTube resolve failed — \(error)")
            return nil
        }
    }

    private func searchTextForPlayback(_ query: String) -> String {
        if query.hasPrefix("spotify:track:"), let pipeIndex = query.firstIndex(of: "|") {
            return String(query[query.index(after: pipeIndex)...])
        }
        return query
    }

    // MARK: - Registry

    func registerTrackId(_ pairs: [(query: String, spotifyId: String)]) {
        for pair in pairs {
            if !pair.query.isEmpty, !pair.spotifyId.isEmpty {
                trackIdRegistry[pair.query] = pair.spotifyId
            }
        }
    }

    func registerMetadata(_ pairs: [(query: String, meta: TrackMatchMetadata)]) {
        for pair in pairs {
            if !pair.query.isEmpty, !pair.meta.title.isEmpty {
                metadataRegistry[pair.query] = pair.meta
            }
        }
    }

    func registerDuration(_ pairs: [(query: String, ms: Int)]) {
        for pair in pairs {
            if !pair.query.isEmpty, pair.ms > 0 {
                durationRegistry[pair.query] = pair.ms
            }
        }
    }

    func registerExplicit(_ pairs: [(query: String, explicit: Bool)]) {
        for pair in pairs {
            if !pair.query.isEmpty {
                explicitRegistry[pair.query] = pair.explicit
            }
        }
    }

    // MARK: - Now Playing (Lock Screen / Control Center)

    private func updateNowPlaying() {
        guard let track = currentTrack else { return }
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = track.title
        info[MPMediaItemPropertyArtist] = track.singer
        info[MPMediaItemPropertyAlbumTitle] = track.album
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentPosition
        info[MPNowPlayingInfoPropertyPlaybackDuration] = duration
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
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let pos = event as? MPChangePlaybackPositionCommandEvent {
                self?.seek(to: pos.positionTime)
            }
            return .success
        }
    }

    // MARK: - Downloads

    func downloadTrack(_ track: Track) async -> Bool {
        guard let streamUrl = await resolveStreamUrl(track), let url = URL(string: streamUrl) else {
            return false
        }
        let dir = UserPreferences.shared.downloadsDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let outFile = dir.appendingPathComponent("\(track.id).m4a")

        do {
            let (tempURL, _) = try await URLSession.shared.download(for: URLRequest(url: url))
            try FileManager.default.moveItem(at: tempURL, to: outFile)
            return true
        } catch {
            print("AudioEngine: Download failed — \(error)")
            return false
        }
    }
}

// Import needed for MPNowPlayingInfoCenter
import MediaPlayer
import UIKit
