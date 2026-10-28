import Foundation

enum YouTubeError: LocalizedError, Sendable {
    case invalidResponse
    case http(Int)
    case unavailable(String)
    case noAudio
    case emptyQuery

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "YouTube returned an unreadable response."
        case .http(let code):
            return "YouTube request failed (HTTP \(code))."
        case .unavailable(let reason):
            return reason.isEmpty ? "This video is unavailable." : reason
        case .noAudio:
            return "No compatible audio stream was found. YouTube may require a client update."
        case .emptyQuery:
            return "Enter something to search for."
        }
    }
}

final class YouTubeClient: @unchecked Sendable {
    static let shared = YouTubeClient()

    /// The player and downloader use the same user agent as the extraction client.
    static let streamUserAgent = "com.google.android.youtube/19.44.38 (Linux; U; Android 14; en_US) gzip"

    private let session: URLSession
    private let apiKey = "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"
    private let baseURL = URL(string: "https://www.youtube.com/youtubei/v1/")!

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = true
        configuration.httpAdditionalHeaders = [
            "Accept-Language": "en-US,en;q=0.9"
        ]
        session = URLSession(configuration: configuration)
    }

    // MARK: - Public API

    func search(query: String, limit: Int = 30) async throws -> [Track] {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw YouTubeError.emptyQuery }

        var lastError: Error?
        for profile in [ClientProfile.android, .ios] {
            do {
                let body: [String: Any] = [
                    "context": ["client": profile.context],
                    "query": clean,
                    "params": "EgIQAQ%3D%3D"
                ]
                let json = try await post("search", profile: profile, body: body)
                let tracks = Array(
                    collectTracks(from: json)
                        .filter { $0.durationMs > 0 }
                        .uniqueByID()
                        .prefix(limit)
                )
                if !tracks.isEmpty {
                    return tracks
                }
            } catch {
                lastError = error
            }
        }

        if let lastError {
            throw lastError
        }
        return []
    }

    /// Related audio for autoplay. Falls back to an artist search when YouTube's
    /// watch-next feed is sparse or unavailable.
    func related(
        videoID: String,
        seedTitle: String,
        seedArtist: String,
        limit: Int = 20
    ) async throws -> [Track] {
        var combined: [Track] = []

        if let direct = try? await directRelated(videoID: videoID, limit: limit) {
            combined = direct
        }

        if combined.count < 5 {
            let query = [seedArtist, seedTitle, "mix"]
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .joined(separator: " ")
            if !query.isEmpty, let fallback = try? await search(query: query, limit: limit) {
                combined.append(contentsOf: fallback)
            }
        }

        return Array(
            combined
                .filter { $0.id != videoID }
                .filter { (30_000...1_200_000).contains($0.durationMs) }
                .uniqueByID()
                .prefix(limit)
        )
    }

    func playbackSource(videoID: String, quality: AudioQuality) async throws -> PlaybackSource {
        var lastReason = ""

        for profile in ClientProfile.playbackProfiles {
            do {
                var body: [String: Any] = [
                    "context": ["client": profile.context],
                    "videoId": videoID,
                    "contentCheckOk": true,
                    "racyCheckOk": true
                ]
                if profile.isEmbedded {
                    body["thirdParty"] = ["embedUrl": "https://www.youtube.com/"]
                }

                let json = try await post("player", profile: profile, body: body)

                if let status = json["playabilityStatus"] as? [String: Any],
                   let state = status["status"] as? String,
                   state != "OK" {
                    lastReason = status["reason"] as? String ?? state
                    continue
                }

                guard let streaming = json["streamingData"] as? [String: Any],
                      let formats = streaming["adaptiveFormats"] as? [[String: Any]] else {
                    continue
                }

                // AVPlayer can decode AAC in an MP4 container. WebM/Opus is not
                // reliably supported on iOS, so only use compatible formats.
                let candidates = formats
                    .compactMap(audioCandidate)
                    .filter { $0.mimeType.contains("mp4") || $0.mimeType.contains("m4a") }

                guard !candidates.isEmpty else {
                    lastReason = "No AAC audio stream was found."
                    continue
                }
                guard let chosen = choose(from: candidates, quality: quality) else { continue }
                return chosen
            } catch {
                lastReason = error.localizedDescription
            }
        }

        if lastReason.isEmpty {
            throw YouTubeError.noAudio
        }
        throw YouTubeError.unavailable(lastReason)
    }

    // MARK: - Requests

    private func post(
        _ endpoint: String,
        profile: ClientProfile,
        body: [String: Any]
    ) async throws -> [String: Any] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(endpoint),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "prettyPrint", value: "false")
        ]
        guard let url = components?.url else { throw YouTubeError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(profile.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(profile.headerName, forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(profile.version, forHTTPHeaderField: "X-YouTube-Client-Version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw YouTubeError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw YouTubeError.http(http.statusCode)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw YouTubeError.invalidResponse
        }
        return json
    }

    private func directRelated(videoID: String, limit: Int) async throws -> [Track] {
        let body: [String: Any] = [
            "context": ["client": ClientProfile.android.context],
            "videoId": videoID
        ]
        let json = try await post("next", profile: .android, body: body)
        return Array(
            collectTracks(from: json)
                .filter { (30_000...1_200_000).contains($0.durationMs) }
                .uniqueByID()
                .prefix(limit)
        )
    }

    // MARK: - Search / related parsing

    private func collectTracks(from json: [String: Any]) -> [Track] {
        var renderers: [[String: Any]] = []
        collectRenderers(json, into: &renderers)
        return renderers.compactMap(track(from:))
    }

    private func collectRenderers(_ value: Any, into result: inout [[String: Any]]) {
        if let dictionary = value as? [String: Any] {
            for key in Self.rendererKeys {
                if let renderer = dictionary[key] as? [String: Any] {
                    result.append(renderer)
                }
            }
            for child in dictionary.values {
                collectRenderers(child, into: &result)
            }
        } else if let array = value as? [Any] {
            for child in array {
                collectRenderers(child, into: &result)
            }
        }
    }

    private func track(from renderer: [String: Any]) -> Track? {
        guard let id = renderer["videoId"] as? String, !id.isEmpty else { return nil }
        guard let title = text(renderer["title"]) ?? text(renderer["headline"]), !title.isEmpty else {
            return nil
        }

        let artist = text(renderer["ownerText"])
            ?? text(renderer["longBylineText"])
            ?? text(renderer["shortBylineText"])
            ?? text(renderer["subtitle"])
            ?? "Unknown artist"

        let duration = durationSeconds(from: renderer)
        guard duration > 0 else { return nil }

        let thumbnails = (renderer["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]]
        let thumbnailURL = thumbnails?.last?["url"] as? String

        return Track(
            id: id,
            title: title,
            artist: artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Unknown artist"
                : artist,
            durationMs: duration * 1000,
            thumbnailURL: thumbnailURL
        )
    }

    private func durationSeconds(from renderer: [String: Any]) -> Int {
        if let lengthText = text(renderer["lengthText"]),
           let seconds = seconds(from: lengthText) {
            return seconds
        }
        if let raw = renderer["lengthSeconds"] as? String, let seconds = Int(raw) {
            return seconds
        }
        if let raw = renderer["lengthSeconds"] as? Int {
            return raw
        }
        return 0
    }

    private func seconds(from value: String) -> Int? {
        let parts = value.split(separator: ":").compactMap { Int($0) }
        guard !parts.isEmpty, parts.count <= 3 else { return nil }
        return parts.reduce(0) { $0 * 60 + $1 }
    }

    private func text(_ value: Any?) -> String? {
        if let string = value as? String { return string }
        guard let dictionary = value as? [String: Any] else { return nil }
        if let simple = dictionary["simpleText"] as? String { return simple }
        if let runs = dictionary["runs"] as? [[String: Any]] {
            let joined = runs.compactMap { $0["text"] as? String }.joined()
            return joined.isEmpty ? nil : joined
        }
        if let content = dictionary["content"] as? String { return content }
        return nil
    }

    // MARK: - Audio streams

    private func audioCandidate(from format: [String: Any]) -> PlaybackSource? {
        guard let mimeType = format["mimeType"] as? String,
              mimeType.hasPrefix("audio/"),
              let urlString = format["url"] as? String,
              let url = URL(string: urlString) else {
            return nil
        }

        let bitrate = integerValue(format["bitrate"])
            ?? integerValue(format["averageBitrate"])
            ?? 0
        let fileExtension: String
        if mimeType.contains("mp4") || mimeType.contains("m4a") {
            fileExtension = "m4a"
        } else if mimeType.contains("webm") {
            fileExtension = "webm"
        } else if mimeType.contains("mpeg") {
            fileExtension = "mp3"
        } else {
            fileExtension = "m4a"
        }

        return PlaybackSource(
            url: url,
            mimeType: mimeType,
            fileExtension: fileExtension,
            bitrate: bitrate
        )
    }

    private func choose(from sources: [PlaybackSource], quality: AudioQuality) -> PlaybackSource? {
        switch quality {
        case .high:
            return sources.max { $0.bitrate < $1.bitrate }
        case .balanced:
            return sources.min {
                abs($0.bitrate - 128_000) < abs($1.bitrate - 128_000)
            }
        case .dataSaver:
            return sources.min { $0.bitrate < $1.bitrate }
        }
    }

    private func integerValue(_ value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String { return Int(string) }
        return nil
    }

    private static let rendererKeys = [
        "videoRenderer",
        "compactVideoRenderer",
        "gridVideoRenderer",
        "playlistVideoRenderer"
    ]
}

// MARK: - InnerTube clients

private struct ClientProfile {
    var name: String
    var version: String
    var headerName: String
    var userAgent: String
    var context: [String: Any]
    var isEmbedded: Bool = false

    static let android = ClientProfile(
        name: "ANDROID",
        version: "19.44.38",
        headerName: "3",
        userAgent: "com.google.android.youtube/19.44.38 (Linux; U; Android 14; en_US) gzip",
        context: [
            "clientName": "ANDROID",
            "clientVersion": "19.44.38",
            "androidSdkVersion": 34,
            "hl": "en",
            "gl": "US",
            "userAgent": "com.google.android.youtube/19.44.38 (Linux; U; Android 14; en_US) gzip"
        ]
    )

    static let ios = ClientProfile(
        name: "IOS",
        version: "19.45.4",
        headerName: "5",
        userAgent: "com.google.ios.youtube/19.45.4 (iPhone16,2; U; CPU iOS 18_1_0 like Mac OS X;)",
        context: [
            "clientName": "IOS",
            "clientVersion": "19.45.4",
            "deviceModel": "iPhone16,2",
            "osName": "iPhone",
            "osVersion": "18.1.0.22B83",
            "hl": "en",
            "gl": "US"
        ]
    )

    static let tv = ClientProfile(
        name: "TVHTML5_SIMPLY_EMBEDDED_PLAYER",
        version: "2.0",
        headerName: "85",
        userAgent: "Mozilla/5.0 (PlayStation; PlayStation 4/12.00) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0 Safari/605.1.15",
        context: [
            "clientName": "TVHTML5_SIMPLY_EMBEDDED_PLAYER",
            "clientVersion": "2.0",
            "clientScreen": "EMBED",
            "hl": "en",
            "gl": "US"
        ],
        isEmbedded: true
    )

    static let playbackProfiles: [ClientProfile] = [.android, .ios, .tv]
}
