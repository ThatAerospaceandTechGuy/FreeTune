import Foundation
import Combine

struct SearchState {
    var query: String = ""
    var results: [Track] = []
    var loading = false
    var hasSearched = false
    var error: String?
}

struct ToastMessage: Identifiable, Equatable, Sendable {
    let id = UUID()
    let text: String

    init(text: String) {
        self.text = text
    }
}

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    let settings: SettingsStore
    let library: LibraryStore
    let player: PlayerManager
    let downloads: DownloadManager

    @Published var search = SearchState()
    @Published var discover = SearchState(query: "Top songs 2026")
    @Published var playlistPickerTrack: Track?
    @Published var playlistDownloadRequest: PlaylistDownloadRequest?
    @Published var toast: ToastMessage?

    private var searchTask: Task<Void, Never>?
    private var discoverTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?

    private init() {
        let settings = SettingsStore()
        let library = LibraryStore()
        self.settings = settings
        self.library = library
        self.player = PlayerManager(settings: settings)
        self.downloads = DownloadManager(library: library, settings: settings)

        downloads.onCompleted = { [weak self] track in
            self?.showToast("Downloaded \(track.title)")
        }
        downloads.onFailed = { [weak self] track, _ in
            self?.showToast("Download failed: \(track.title)")
        }
    }

    // MARK: - Search

    func setSearchQuery(_ value: String) {
        search.query = value
        search.error = nil
        searchTask?.cancel()

        let query = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            search.results = []
            search.loading = false
            search.hasSearched = false
            return
        }

        search.loading = true
        search.hasSearched = true
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 650_000_000)
            guard !Task.isCancelled else { return }
            await self?.performSearch(query)
        }
    }

    func submitSearch() {
        searchTask?.cancel()
        let query = search.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        search.loading = true
        search.hasSearched = true
        search.error = nil
        searchTask = Task { [weak self] in
            await self?.performSearch(query)
        }
    }

    private func performSearch(_ query: String) async {
        do {
            let results = try await YouTubeClient.shared.search(query: query)
            guard !Task.isCancelled,
                  search.query.trimmingCharacters(in: .whitespacesAndNewlines) == query else {
                return
            }
            search.results = results
            search.loading = false
            search.hasSearched = true
            search.error = nil
        } catch {
            guard !Task.isCancelled,
                  search.query.trimmingCharacters(in: .whitespacesAndNewlines) == query else {
                return
            }
            search.loading = false
            search.hasSearched = true
            search.error = friendly(error)
        }
    }

    // MARK: - Discover

    func loadDiscover(_ query: String? = nil) {
        let target = (query ?? discover.query)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return }

        discoverTask?.cancel()
        discover.query = target
        discover.loading = true
        discover.hasSearched = true
        discover.error = nil

        discoverTask = Task { [weak self] in
            guard let self else { return }
            do {
                let results = try await YouTubeClient.shared.search(query: target)
                guard !Task.isCancelled, self.discover.query == target else { return }
                self.discover.results = results
                self.discover.loading = false
                self.discover.error = nil
            } catch {
                guard !Task.isCancelled, self.discover.query == target else { return }
                self.discover.loading = false
                self.discover.error = self.friendly(error)
            }
        }
    }

    func ensureDiscoverLoaded() {
        if discover.results.isEmpty && !discover.loading && discover.error == nil {
            loadDiscover(discover.query)
        }
    }

    // MARK: - Playback

    func play(_ track: Track, queue: [Track]? = nil) {
        player.play(track, queue: queue ?? [track])
        library.markPlayed(track)
    }

    func playPlaylist(_ playlist: Playlist, tracks: [Track]? = nil, shuffle: Bool = false) {
        let available = tracks ?? library.tracks(in: playlist)
        guard !available.isEmpty else {
            showToast("\(playlist.name) is empty")
            return
        }
        let ordered = shuffle ? available.shuffled() : available
        player.play(ordered[0], queue: ordered)
        library.markPlayed(ordered[0])
        showToast(shuffle ? "Shuffling \(playlist.name)" : "Playing \(playlist.name)")
    }

    func toggleLike(_ track: Track) {
        library.toggleLike(track)
    }

    func isLiked(_ track: Track) -> Bool {
        library.isLiked(id: track.id)
    }

    func isDownloaded(_ track: Track) -> Bool {
        library.isDownloaded(id: track.id)
    }

    // MARK: - Downloads

    func download(_ track: Track, folder: String? = nil, replace: Bool = false) {
        if !replace {
            if downloads.isActive(track.id) {
                showToast("Download already queued")
                return
            }
            if library.isDownloaded(id: track.id) {
                showToast("Already downloaded")
                return
            }
        }

        downloads.download(track: track, folder: folder, replace: replace)
        showToast(replace ? "Re-downloading \(track.title)" : "Download queued")
    }

    func downloadPlaylist(
        _ request: PlaylistDownloadRequest,
        quality: AudioQuality,
        skipDownloaded: Bool
    ) {
        let activeIDs = Set(
            downloads.statuses.values
                .filter(\.isActive)
                .map(\.track.id)
        )
        let pending = request.tracks.filter { track in
            !activeIDs.contains(track.id) &&
                (!skipDownloaded || !library.isDownloaded(id: track.id))
        }

        guard !pending.isEmpty else {
            showToast("Everything in \(request.playlist.name) is already downloaded or queued")
            return
        }

        for track in pending {
            downloads.download(
                track: track,
                quality: quality,
                folder: request.playlist.name,
                replace: !skipDownloaded
            )
        }

        let verb = skipDownloaded ? "Downloading" : "Re-downloading"
        showToast("\(verb) \(pending.count) songs to \(request.playlist.name)/")
    }

    func requestPlaylistDownload(_ playlist: Playlist) {
        let tracks = library.tracks(in: playlist)
        guard !tracks.isEmpty else {
            showToast("\(playlist.name) is empty")
            return
        }
        playlistDownloadRequest = PlaylistDownloadRequest(playlist: playlist, tracks: tracks)
    }

    func dismissPlaylistDownload() {
        playlistDownloadRequest = nil
    }

    func confirmPlaylistDownload(
        _ request: PlaylistDownloadRequest,
        quality: AudioQuality,
        skipDownloaded: Bool
    ) {
        downloadPlaylist(request, quality: quality, skipDownloaded: skipDownloaded)
        playlistDownloadRequest = nil
    }

    func retryDownload(_ status: DownloadStatus) {
        download(status.track, replace: true)
    }

    func dismissDownload(_ trackID: String) {
        downloads.dismiss(trackID)
    }

    func removeDownload(_ track: Track) {
        library.removeDownload(track)
        showToast("Download removed")
    }

    // MARK: - Playlists

    @discardableResult
    func createPlaylist(_ name: String) -> Playlist? {
        guard let playlist = library.createPlaylist(name: name) else {
            showToast("Playlist name can't be empty")
            return nil
        }
        showToast("Playlist created")
        return playlist
    }

    func addToPlaylist(_ track: Track, playlist: Playlist) {
        let added = library.addToPlaylist(track, playlistID: playlist.id)
        playlistPickerTrack = nil
        showToast(added ? "Added to \(playlist.name)" : "Already in \(playlist.name)")
    }

    @discardableResult
    func createPlaylistAndAdd(_ name: String, track: Track) -> Bool {
        guard let playlist = library.createPlaylist(name: name) else {
            showToast("Playlist name can't be empty")
            return false
        }
        _ = library.addToPlaylist(track, playlistID: playlist.id)
        playlistPickerTrack = nil
        showToast("Added to \(playlist.name)")
        return true
    }

    func removeFromPlaylist(_ track: Track, playlist: Playlist) {
        library.removeFromPlaylist(track, playlistID: playlist.id)
        showToast("Removed from playlist")
    }

    func deletePlaylist(_ playlist: Playlist) {
        library.deletePlaylist(playlist)
        showToast("Playlist deleted")
    }

    // MARK: - Privacy

    func clearRecent() {
        library.clearRecent()
        showToast("Recent history cleared")
    }

    func clearAll() {
        searchesCancel()
        downloads.cancelAll()
        player.stop()
        settings.reset()
        library.clearAll()
        playlistPickerTrack = nil
        playlistDownloadRequest = nil
        showToast("All data erased")
    }

    private func searchesCancel() {
        searchTask?.cancel()
        discoverTask?.cancel()
        search = SearchState()
    }

    // MARK: - Toasts

    func showToast(_ text: String) {
        let message = ToastMessage(text: text)
        toast = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            guard !Task.isCancelled else { return }
            guard let self, self.toast?.id == message.id else { return }
            self.toast = nil
        }
    }

    private func friendly(_ error: Error) -> String {
        let message = error.localizedDescription
        let lower = message.lowercased()
        if message.contains("429") ||
            lower.contains("rate limit") ||
            lower.contains("recaptcha") {
            return "YouTube is busy or rate-limiting requests. Try again in a minute."
        }
        if (error as NSError).domain == NSURLErrorDomain {
            return "Network error. Check your connection and try again."
        }
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Something went wrong." : String(trimmed.prefix(180))
    }
}
