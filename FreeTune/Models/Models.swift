import Foundation

struct Track: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var title: String
    var artist: String
    var durationMs: Int
    var thumbnailURL: String?
    var localPath: String?
    var liked: Bool = false
    var lastPlayedAt: Date?

    var isDownloaded: Bool {
        guard let localPath, !localPath.isEmpty else { return false }
        return FileManager.default.fileExists(atPath: localPath)
    }

    var durationSeconds: Double {
        Double(durationMs) / 1000.0
    }

    var durationText: String {
        Self.formatDuration(durationMs)
    }

    static func formatDuration(_ milliseconds: Int) -> String {
        let totalSeconds = max(0, milliseconds / 1000)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    static func formatDuration(seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        return formatDuration(Int(seconds * 1000))
    }
}

struct Playlist: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var createdAt: Date
    var trackIDs: [String]

    var trackCount: Int { trackIDs.count }
}

enum AudioQuality: String, Codable, CaseIterable, Identifiable, Sendable {
    case high
    case balanced
    case dataSaver

    var id: String { rawValue }

    var title: String {
        switch self {
        case .high: return "Best available"
        case .balanced: return "Balanced"
        case .dataSaver: return "Data saver"
        }
    }

    var detail: String {
        switch self {
        case .high: return "Highest compatible YouTube audio bitrate"
        case .balanced: return "Around 128-160 kbps"
        case .dataSaver: return "Lowest bitrate, smallest files"
        }
    }
}

struct DownloadStatus: Identifiable, Equatable, Sendable {
    enum State: String, Equatable, Sendable {
        case queued
        case running
        case failed
    }

    var id: String { track.id }
    var track: Track
    var progress: Double
    var state: State
    var message: String?

    var isActive: Bool {
        state == .queued || state == .running
    }
}

struct PlaylistDownloadRequest: Identifiable, Sendable {
    var id: UUID { playlist.id }
    var playlist: Playlist
    var tracks: [Track]
}

struct PlaybackSource: Sendable {
    var url: URL
    var mimeType: String
    var fileExtension: String
    var bitrate: Int
}

extension Array where Element == Track {
    func uniqueByID() -> [Track] {
        var seen = Set<String>()
        return filter { seen.insert($0.id).inserted }
    }
}
