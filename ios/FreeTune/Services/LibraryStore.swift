import Foundation
import Combine

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var tracks: [Track] = []
    @Published private(set) var playlists: [Playlist] = []

    private let storeURL: URL
    private let fileManager: FileManager

    init() {
        let manager = FileManager.default
        let support = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? manager.temporaryDirectory
        let folder = support.appendingPathComponent("FreeTune", isDirectory: true)
        try? manager.createDirectory(at: folder, withIntermediateDirectories: true)
        storeURL = folder.appendingPathComponent("library.json")
        fileManager = manager

        try? manager.createDirectory(
            at: Self.downloadsURL,
            withIntermediateDirectories: true
        )

        load()
    }

    var liked: [Track] {
        tracks.filter(\.liked).sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var downloaded: [Track] {
        tracks.filter(\.isDownloaded).sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    var recent: [Track] {
        tracks
            .filter { $0.lastPlayedAt != nil }
            .sorted { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) }
    }

    func track(id: String) -> Track? {
        tracks.first { $0.id == id }
    }

    func playlist(id: UUID) -> Playlist? {
        playlists.first { $0.id == id }
    }

    func tracks(in playlist: Playlist) -> [Track] {
        playlist.trackIDs.compactMap { track(id: $0) }
    }

    func isLiked(id: String) -> Bool {
        track(id: id)?.liked ?? false
    }

    func isDownloaded(id: String) -> Bool {
        track(id: id)?.isDownloaded ?? false
    }

    func toggleLike(_ track: Track) {
        if let index = tracks.firstIndex(where: { $0.id == track.id }) {
            tracks[index].liked.toggle()
        } else {
            var newTrack = track
            newTrack.liked = true
            tracks.append(newTrack)
        }
        save()
    }

    func markPlayed(_ track: Track) {
        if let index = tracks.firstIndex(where: { $0.id == track.id }) {
            tracks[index].title = track.title
            tracks[index].artist = track.artist
            tracks[index].durationMs = track.durationMs
            tracks[index].thumbnailURL = track.thumbnailURL
            tracks[index].lastPlayedAt = Date()
        } else {
            var newTrack = track
            newTrack.lastPlayedAt = Date()
            tracks.append(newTrack)
        }
        save()
    }

    func saveDownload(_ track: Track, path: String) {
        if let index = tracks.firstIndex(where: { $0.id == track.id }) {
            let oldPath = tracks[index].localPath
            if let oldPath, oldPath != path {
                try? fileManager.removeItem(atPath: oldPath)
            }
            tracks[index].title = track.title
            tracks[index].artist = track.artist
            tracks[index].durationMs = track.durationMs
            tracks[index].thumbnailURL = track.thumbnailURL
            tracks[index].localPath = path
        } else {
            var newTrack = track
            newTrack.localPath = path
            tracks.append(newTrack)
        }
        save()
    }

    func removeDownload(_ track: Track) {
        if let path = track.localPath {
            try? fileManager.removeItem(atPath: path)
        }
        if let index = tracks.firstIndex(where: { $0.id == track.id }) {
            tracks[index].localPath = nil
        }
        save()
    }

    @discardableResult
    func createPlaylist(name: String) -> Playlist? {
        let clean = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
        guard !clean.isEmpty else { return nil }
        let playlist = Playlist(
            id: UUID(),
            name: clean,
            createdAt: Date(),
            trackIDs: []
        )
        playlists.append(playlist)
        save()
        return playlist
    }

    @discardableResult
    func addToPlaylist(_ track: Track, playlistID: UUID) -> Bool {
        guard let playlistIndex = playlists.firstIndex(where: { $0.id == playlistID }) else {
            return false
        }
        if !tracks.contains(where: { $0.id == track.id }) {
            tracks.append(track)
        }
        guard !playlists[playlistIndex].trackIDs.contains(track.id) else {
            return false
        }
        playlists[playlistIndex].trackIDs.append(track.id)
        save()
        return true
    }

    func removeFromPlaylist(_ track: Track, playlistID: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        playlists[index].trackIDs.removeAll { $0 == track.id }
        save()
    }

    func deletePlaylist(_ playlist: Playlist) {
        playlists.removeAll { $0.id == playlist.id }
        save()
    }

    func clearRecent() {
        for index in tracks.indices {
            tracks[index].lastPlayedAt = nil
        }
        save()
    }

    func clearAll() {
        tracks = []
        playlists = []
        try? fileManager.removeItem(at: storeURL)
        try? fileManager.removeItem(at: Self.downloadsURL)
        try? fileManager.createDirectory(
            at: Self.downloadsURL,
            withIntermediateDirectories: true
        )
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let stored = try? decoder.decode(StoredData.self, from: data) else { return }
        tracks = stored.tracks
        playlists = stored.playlists
    }

    private func save() {
        let stored = StoredData(tracks: tracks, playlists: playlists)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(stored) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }

    // MARK: - Files

    static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }

    static var downloadsURL: URL {
        documentsURL.appendingPathComponent("FreeTune", isDirectory: true)
    }

    static func folderURL(named rawName: String?) -> URL {
        guard let folder = folderName(rawName) else { return downloadsURL }
        return downloadsURL.appendingPathComponent(folder, isDirectory: true)
    }

    static func folderName(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let clean = raw
            .replacingOccurrences(of: "[\\\\/:*?\"<>|\\n\\r]", with: "_", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let limited = String(clean.prefix(60))
        return limited.isEmpty ? nil : limited
    }

    static func safeFileName(_ raw: String) -> String {
        let clean = raw
            .replacingOccurrences(of: "[\\\\/:*?\"<>|\\n\\r]", with: "_", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let limited = String(clean.prefix(90))
        return limited.isEmpty ? "audio" : limited
    }

    static func displayName(for track: Track) -> String {
        if !track.artist.isEmpty,
           !track.title.lowercased().hasPrefix(track.artist.lowercased()) {
            return "\(track.artist) - \(track.title)"
        }
        return track.title
    }

    private struct StoredData: Codable {
        var tracks: [Track]
        var playlists: [Playlist]
    }
}
