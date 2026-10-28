import AVFoundation
import MediaPlayer
import UIKit
import Combine

@MainActor
final class PlayerManager: ObservableObject {
    @Published private(set) var current: Track?
    @Published private(set) var queue: [Track] = []
    @Published private(set) var queueIndex = -1
    @Published private(set) var isPlaying = false
    @Published private(set) var isLoading = false
    @Published private(set) var autoplayLoading = false
    @Published private(set) var position: Double = 0
    @Published private(set) var duration: Double = 0
    @Published var error: String?

    private let settings: SettingsStore
    private let player = AVPlayer()

    private var loadTask: Task<Void, Never>?
    private var autoplayTask: Task<Void, Never>?
    private var artworkTask: Task<Void, Never>?
    private var timeObserver: Any?
    private var timeControlObservation: NSKeyValueObservation?
    private var itemStatusObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private var routeObserver: NSObjectProtocol?

    private var wantsToPlay = false
    private var retryCount = 0
    private var wasPlayingBeforeInterruption = false
    private var artwork: UIImage?
    private var artworkTrackID: String?
    private var lastNowPlayingSecond = -1

    init(settings: SettingsStore) {
        self.settings = settings
        configureAudioSession()
        player.automaticallyWaitsToMinimizeStalling = true
        setupObservers()
        setupRemoteCommands()
    }

    // MARK: - Public controls

    func play(_ track: Track, queue newQueue: [Track]? = nil) {
        let proposed = (newQueue?.isEmpty == false) ? newQueue! : [track]
        let ordered = proposed.contains(where: { $0.id == track.id }) ? proposed : [track]

        queue = ordered
        queueIndex = ordered.firstIndex(where: { $0.id == track.id }) ?? 0
        retryCount = 0
        autoplayTask?.cancel()
        autoplayTask = nil
        autoplayLoading = false

        if current?.id != track.id {
            artwork = nil
            artworkTrackID = nil
        }
        loadCurrent()
    }

    func togglePlayPause() {
        if wantsToPlay || isPlaying {
            pause()
        } else {
            resume()
        }
    }

    func resume() {
        guard current != nil else { return }
        wantsToPlay = true
        activateAudioSession()
        player.play()
        if player.currentItem?.status == .readyToPlay {
            isPlaying = true
        }
        updateNowPlaying()
    }

    func pause() {
        wantsToPlay = false
        player.pause()
        isPlaying = false
        autoplayTask?.cancel()
        autoplayTask = nil
        autoplayLoading = false
        updateNowPlaying()
    }

    func next() {
        guard !queue.isEmpty else { return }
        autoplayTask?.cancel()
        autoplayTask = nil
        autoplayLoading = false

        if queueIndex < queue.count - 1 {
            queueIndex += 1
            retryCount = 0
            loadCurrent()
        } else {
            onTrackEnded()
        }
    }

    func previous() {
        guard !queue.isEmpty else { return }
        autoplayTask?.cancel()
        autoplayTask = nil
        autoplayLoading = false
        if queueIndex > 0 {
            queueIndex -= 1
            retryCount = 0
            loadCurrent()
        } else {
            seek(to: 0)
        }
    }

    func seek(to seconds: Double) {
        guard current != nil else { return }
        var target = max(0, seconds)
        if duration > 0 {
            target = min(target, duration)
        }
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
        position = target
        updateNowPlaying()
    }

    func stop() {
        loadTask?.cancel()
        loadTask = nil
        autoplayTask?.cancel()
        autoplayTask = nil
        artworkTask?.cancel()
        artworkTask = nil

        wantsToPlay = false
        player.pause()
        player.replaceCurrentItem(with: nil)

        current = nil
        queue = []
        queueIndex = -1
        isPlaying = false
        isLoading = false
        autoplayLoading = false
        error = nil
        position = 0
        duration = 0
        artwork = nil
        artworkTrackID = nil

        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPNowPlayingInfoCenter.default().playbackState = .stopped
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    // MARK: - Loading

    private func loadCurrent() {
        guard queue.indices.contains(queueIndex) else { return }
        let track = queue[queueIndex]

        loadTask?.cancel()
        if current?.id != track.id {
            artwork = nil
            artworkTrackID = nil
        }

        current = track
        isLoading = true
        error = nil
        position = 0
        duration = track.durationSeconds
        wantsToPlay = true
        activateAudioSession()
        updateNowPlaying()

        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let localPath = track.localPath
                let isLocal = localPath.map { FileManager.default.fileExists(atPath: $0) } ?? false
                let url: URL
                if isLocal, let localPath {
                    url = URL(fileURLWithPath: localPath)
                } else {
                    let source = try await YouTubeClient.shared.playbackSource(
                        videoID: track.id,
                        quality: self.settings.quality
                    )
                    url = source.url
                }
                try Task.checkCancellation()
                self.startPlayback(url: url, track: track, isLocal: isLocal)
            } catch is CancellationError {
                return
            } catch {
                self.handleLoadError(error, track: track)
            }
        }
    }

    private func startPlayback(url: URL, track: Track, isLocal: Bool) {
        guard current?.id == track.id else { return }

        let asset: AVURLAsset
        if isLocal {
            asset = AVURLAsset(url: url)
        } else {
            let headers = [
                "User-Agent": YouTubeClient.streamUserAgent,
                "Referer": "https://www.youtube.com/"
            ]
            asset = AVURLAsset(
                url: url,
                options: ["AVURLAssetHTTPHeaderFieldsKey": headers]
            )
        }

        let item = AVPlayerItem(asset: asset)
        itemStatusObservation?.invalidate()
        itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] observed, _ in
            let rawStatus = observed.status.rawValue
            let message = observed.error?.localizedDescription
            Task { @MainActor [weak self] in
                self?.handleItemStatus(rawStatus, errorMessage: message, track: track)
            }
        }

        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.onTrackEnded()
            }
        }

        player.replaceCurrentItem(with: item)
        player.play()
        updateNowPlaying()
    }

    private func handleItemStatus(
        _ rawStatus: Int,
        errorMessage: String?,
        track: Track
    ) {
        guard current?.id == track.id,
              let status = AVPlayerItem.Status(rawValue: rawStatus) else {
            return
        }

        switch status {
        case .readyToPlay:
            isLoading = false
            retryCount = 0
            if let itemDuration = player.currentItem?.duration.seconds,
               itemDuration.isFinite,
               itemDuration > 0 {
                duration = itemDuration
            }
            if wantsToPlay {
                player.play()
            }
            updateNowPlaying()

        case .failed:
            isLoading = false
            if !track.isDownloaded, retryCount < 1 {
                retryCount += 1
                loadTask?.cancel()
                loadTask = Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    guard !Task.isCancelled else { return }
                    self?.loadCurrent()
                }
            } else {
                wantsToPlay = false
                isPlaying = false
                error = errorMessage ?? "Playback failed."
                updateNowPlaying()
            }

        default:
            break
        }
    }

    private func handleLoadError(_ error: Error, track: Track) {
        guard current?.id == track.id else { return }
        if !track.isDownloaded, retryCount < 1 {
            retryCount += 1
            loadTask?.cancel()
            loadTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 700_000_000)
                guard !Task.isCancelled else { return }
                self?.loadCurrent()
            }
            return
        }
        isLoading = false
        wantsToPlay = false
        isPlaying = false
        self.error = Self.friendly(error)
        updateNowPlaying()
    }

    // MARK: - Queue / autoplay

    private func onTrackEnded() {
        if queueIndex < queue.count - 1 {
            queueIndex += 1
            retryCount = 0
            loadCurrent()
            return
        }

        guard let seed = current else {
            isPlaying = false
            updateNowPlaying()
            return
        }

        if !settings.autoplay {
            wantsToPlay = false
            isPlaying = false
            updateNowPlaying()
            return
        }

        if autoplayTask != nil { return }

        autoplayLoading = true
        error = nil
        autoplayTask = Task { [weak self] in
            guard let self else { return }
            do {
                let related = try await YouTubeClient.shared.related(
                    videoID: seed.id,
                    seedTitle: seed.title,
                    seedArtist: seed.artist,
                    limit: 20
                )
                self.autoplayLoading = false
                self.autoplayTask = nil

                guard !Task.isCancelled, self.current?.id == seed.id else { return }
                guard self.settings.autoplay else { return }

                let knownIDs = Set(self.queue.map(\.id))
                let fresh = related.filter {
                    $0.id != seed.id && !knownIDs.contains($0.id)
                }
                guard !fresh.isEmpty else {
                    self.wantsToPlay = false
                    self.isPlaying = false
                    self.error = "Autoplay couldn't find more songs right now."
                    return
                }

                self.queue.append(contentsOf: fresh.prefix(15))
                self.queueIndex += 1
                self.retryCount = 0
                self.loadCurrent()
            } catch {
                self.autoplayLoading = false
                self.autoplayTask = nil
                guard !Task.isCancelled else { return }
                self.wantsToPlay = false
                self.isPlaying = false
                self.error = Self.friendly(error)
            }
        }
    }

    // MARK: - Observers

    private func setupObservers() {
        timeControlObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] observed, _ in
            let playing = observed.timeControlStatus == .playing
            Task { @MainActor [weak self] in
                self?.handleTimeControl(playing)
            }
        }

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            let seconds = time.seconds
            Task { @MainActor [weak self] in
                self?.updatePosition(seconds)
            }
        }

        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: rawType) else {
                return
            }
            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
            Task { @MainActor [weak self] in
                self?.handleInterruption(type: type, options: options)
            }
        }

        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt ?? 0
            let disconnected = AVAudioSession.RouteChangeReason(rawValue: rawReason) == .oldDeviceUnavailable
            guard disconnected else { return }
            Task { @MainActor [weak self] in
                self?.pause()
            }
        }
    }

    private func handleTimeControl(_ playing: Bool) {
        isPlaying = playing
        updateNowPlaying()
    }

    private func updatePosition(_ seconds: Double) {
        guard current != nil else { return }
        if seconds.isFinite, seconds >= 0 {
            position = seconds
        }
        if let itemDuration = player.currentItem?.duration.seconds,
           itemDuration.isFinite,
           itemDuration > 0 {
            duration = itemDuration
        }
        let wholeSecond = Int(position)
        if wholeSecond != lastNowPlayingSecond {
            lastNowPlayingSecond = wholeSecond
            updateNowPlaying()
        }
    }

    private func handleInterruption(
        type: AVAudioSession.InterruptionType,
        options: AVAudioSession.InterruptionOptions
    ) {
        switch type {
        case .began:
            wasPlayingBeforeInterruption = wantsToPlay || isPlaying
            pause()
        case .ended:
            if options.contains(.shouldResume), wasPlayingBeforeInterruption {
                resume()
            }
            wasPlayingBeforeInterruption = false
        @unknown default:
            break
        }
    }

    // MARK: - Audio session

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
    }

    private func activateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    // MARK: - Now playing / remote controls

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.nextTrackCommand.isEnabled = true
        center.previousTrackCommand.isEnabled = true
        center.changePlaybackPositionCommand.isEnabled = true

        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.resume()
            }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pause()
            }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.togglePlayPause()
            }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.next()
            }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.previous()
            }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let newPosition = event.positionTime
            Task { @MainActor [weak self] in
                self?.seek(to: newPosition)
            }
            return .success
        }
    }

    private func updateNowPlaying() {
        let infoCenter = MPNowPlayingInfoCenter.default()
        guard let track = current else {
            infoCenter.nowPlayingInfo = nil
            infoCenter.playbackState = .stopped
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyAlbumTitle: "FreeTune",
            MPMediaItemPropertyPlaybackDuration: duration > 0 ? duration : track.durationSeconds,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: position,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue
        ]

        if let artwork {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in
                artwork
            }
        }

        infoCenter.nowPlayingInfo = info
        infoCenter.playbackState = isPlaying ? .playing : .paused

        if artworkTrackID != track.id {
            artworkTrackID = track.id
            refreshArtwork(for: track)
        }
    }

    private func refreshArtwork(for track: Track) {
        artworkTask?.cancel()
        guard let url = Self.imageURL(from: track.thumbnailURL) else {
            artwork = nil
            return
        }

        artworkTask = Task { [weak self] in
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled,
                      let self,
                      self.current?.id == track.id,
                      let image = UIImage(data: data) else {
                    return
                }
                self.artwork = image
                self.updateNowPlaying()
            } catch {
                return
            }
        }
    }

    private static func imageURL(from raw: String?) -> URL? {
        guard let raw, !raw.isEmpty else { return nil }
        if raw.hasPrefix("//") {
            return URL(string: "https:" + raw)
        }
        return URL(string: raw)
    }

    private static func friendly(_ error: Error) -> String {
        let message = error.localizedDescription
        let lower = message.lowercased()
        if message.contains("429") ||
            lower.contains("rate limit") ||
            lower.contains("recaptcha") {
            return "YouTube is rate-limiting requests. Try again in a minute."
        }
        if (error as NSError).domain == NSURLErrorDomain {
            return "Network error. Check your connection and try again."
        }
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Playback failed." : String(trimmed.prefix(180))
    }
}
