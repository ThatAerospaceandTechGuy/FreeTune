import Foundation
import Network
import Combine

@MainActor
final class DownloadManager: ObservableObject {
    @Published private(set) var statuses: [String: DownloadStatus] = [:]

    var onCompleted: ((Track) -> Void)?
    var onFailed: ((Track, String) -> Void)?

    private let library: LibraryStore
    private let settings: SettingsStore
    private let service: BackgroundDownloadService
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.freetune.network-monitor")
    private var isOnWiFi = false
    private var didStartMonitor = false
    private var waiting: [String: PrepareRequest] = [:]
    private var tasks: [String: URLSessionDownloadTask] = [:]
    private var cancellables = Set<AnyCancellable>()

    init(library: LibraryStore, settings: SettingsStore) {
        self.library = library
        self.settings = settings
        self.service = .shared
        configureService()
        observeSettings()
        startMonitor()
        restoreTasks()
    }

    var activeStatuses: [DownloadStatus] {
        statuses.values
            .filter(\.isActive)
            .sorted { $0.track.title.localizedCaseInsensitiveCompare($1.track.title) == .orderedAscending }
    }

    var failedStatuses: [DownloadStatus] {
        statuses.values
            .filter { $0.state == .failed }
            .sorted { $0.track.title.localizedCaseInsensitiveCompare($1.track.title) == .orderedAscending }
    }

    func isActive(_ trackID: String) -> Bool {
        statuses[trackID]?.isActive == true
    }

    func status(for trackID: String) -> DownloadStatus? {
        statuses[trackID]
    }

    func download(
        track: Track,
        quality: AudioQuality? = nil,
        folder: String? = nil,
        replace: Bool = false
    ) {
        if !replace {
            if isActive(track.id) { return }
            if library.isDownloaded(id: track.id) { return }
        }

        if replace, let existing = tasks[track.id] {
            existing.cancel()
            tasks[track.id] = nil
        }

        let request = PrepareRequest(
            track: track,
            quality: quality ?? settings.quality,
            folder: folder
        )
        let waitingForWiFi = settings.wifiOnly && !isOnWiFi
        statuses[track.id] = DownloadStatus(
            track: track,
            progress: 0,
            state: .queued,
            message: waitingForWiFi ? "Waiting for Wi-Fi" : "Preparing…"
        )

        if waitingForWiFi {
            waiting[track.id] = request
            return
        }

        waiting[track.id] = nil
        Task { [weak self] in
            await self?.prepareAndStart(request)
        }
    }

    func retry(_ status: DownloadStatus) {
        download(track: status.track, replace: true)
    }

    func dismiss(_ trackID: String) {
        statuses[trackID] = nil
    }

    func cancelAll() {
        for task in tasks.values {
            task.cancel()
        }
        tasks.removeAll()
        waiting.removeAll()
        statuses.removeAll()
        service.session.getAllTasks { tasks in
            for task in tasks {
                task.cancel()
            }
        }
    }

    // MARK: - Service wiring

    private func configureService() {
        service.onProgress = { [weak self] task, progress in
            guard let job = Self.job(from: task) else { return }
            Task { @MainActor [weak self] in
                self?.handleProgress(job: job, progress: progress)
            }
        }

        service.onFinish = { [weak self] task, staging in
            guard let job = Self.job(from: task) else {
                try? FileManager.default.removeItem(at: staging)
                return
            }
            Task { @MainActor [weak self] in
                self?.handleFinish(job: job, staging: staging)
            }
        }

        service.onError = { [weak self] task, error in
            guard let job = Self.job(from: task) else { return }
            let message = Self.friendly(error)
            Task { @MainActor [weak self] in
                self?.handleError(job: job, message: message)
            }
        }
    }

    private func observeSettings() {
        settings.$wifiOnly
            .dropFirst()
            .sink { [weak self] wifiOnly in
                guard !wifiOnly else { return }
                Task { @MainActor [weak self] in
                    self?.startAllWaiting()
                }
            }
            .store(in: &cancellables)
    }

    private func startMonitor() {
        guard !didStartMonitor else { return }
        didStartMonitor = true
        monitor.pathUpdateHandler = { [weak self] path in
            let onWiFi = path.status == .satisfied && path.usesInterfaceType(.wifi)
            Task { @MainActor [weak self] in
                self?.handleNetwork(onWiFi: onWiFi)
            }
        }
        monitor.start(queue: monitorQueue)
    }

    private func handleNetwork(onWiFi: Bool) {
        let wasOnWiFi = isOnWiFi
        isOnWiFi = onWiFi
        if onWiFi && !wasOnWiFi {
            startAllWaiting()
        }
    }

    private func startAllWaiting() {
        let pending = waiting
        waiting.removeAll()
        for request in pending.values {
            statuses[request.track.id]?.message = "Preparing…"
            Task { [weak self] in
                await self?.prepareAndStart(request)
            }
        }
    }

    private func restoreTasks() {
        service.session.getAllTasks { [weak self] tasks in
            let jobs = tasks.compactMap { Self.job(from: $0) }
            Task { @MainActor [weak self] in
                guard let self else { return }
                for job in jobs where self.statuses[job.track.id] == nil {
                    self.statuses[job.track.id] = DownloadStatus(
                        track: job.track,
                        progress: 0,
                        state: .running,
                        message: "Resuming…"
                    )
                }
            }
        }
    }

    // MARK: - Download lifecycle

    private func prepareAndStart(_ request: PrepareRequest) async {
        let track = request.track
        guard statuses[track.id] != nil else { return }

        do {
            let source = try await YouTubeClient.shared.playbackSource(
                videoID: track.id,
                quality: request.quality
            )
            guard statuses[track.id] != nil else { return }

            let folderName = LibraryStore.folderName(request.folder)
            let folder = LibraryStore.folderURL(named: folderName)
            try FileManager.default.createDirectory(
                at: folder,
                withIntermediateDirectories: true
            )

            let baseName = String(
                LibraryStore.safeFileName(LibraryStore.displayName(for: track)).prefix(80)
            )
            let fileName = "\(baseName.isEmpty ? track.id : baseName) [\(track.id)].\(source.fileExtension)"
            let target = folder.appendingPathComponent(fileName)

            if Self.fileSize(at: target) > 0 {
                library.saveDownload(track, path: target.path)
                statuses[track.id] = nil
                onCompleted?(track)
                return
            }

            var urlRequest = URLRequest(url: source.url)
            urlRequest.setValue(YouTubeClient.streamUserAgent, forHTTPHeaderField: "User-Agent")
            urlRequest.setValue("https://www.youtube.com/", forHTTPHeaderField: "Referer")
            urlRequest.allowsCellularAccess = !settings.wifiOnly
            urlRequest.timeoutInterval = 60

            let job = DownloadJob(
                track: track,
                fileName: fileName,
                folderName: folderName
            )
            let data = try JSONEncoder().encode(job)
            let task = service.session.downloadTask(with: urlRequest)
            task.taskDescription = String(data: data, encoding: .utf8)
            tasks[track.id] = task
            statuses[track.id] = DownloadStatus(
                track: track,
                progress: 0,
                state: .running,
                message: "Downloading…"
            )
            task.resume()
        } catch {
            guard statuses[track.id] != nil else { return }
            fail(track: track, message: Self.friendly(error))
        }
    }

    private func handleProgress(job: DownloadJob, progress: Double) {
        guard var status = statuses[job.track.id], status.state != .failed else { return }
        status.progress = min(max(progress, 0), 1)
        status.state = .running
        status.message = nil
        statuses[job.track.id] = status
    }

    private func handleFinish(job: DownloadJob, staging: URL) {
        let folder = LibraryStore.folderURL(named: job.folderName)
        let target = folder.appendingPathComponent(job.fileName)
        do {
            try FileManager.default.createDirectory(
                at: folder,
                withIntermediateDirectories: true
            )
            if FileManager.default.fileExists(atPath: target.path) {
                try? FileManager.default.removeItem(at: target)
            }
            try FileManager.default.moveItem(at: staging, to: target)
            library.saveDownload(job.track, path: target.path)
            statuses[job.track.id] = nil
            tasks[job.track.id] = nil
            onCompleted?(job.track)
        } catch {
            try? FileManager.default.removeItem(at: staging)
            fail(
                track: job.track,
                message: "Could not save download: \(error.localizedDescription)"
            )
        }
    }

    private func handleError(job: DownloadJob, message: String) {
        fail(track: job.track, message: message)
    }

    private func fail(track: Track, message: String) {
        statuses[track.id] = DownloadStatus(
            track: track,
            progress: 0,
            state: .failed,
            message: message
        )
        tasks[track.id] = nil
        onFailed?(track, message)
    }

    // MARK: - Helpers

    private struct PrepareRequest: Sendable {
        var track: Track
        var quality: AudioQuality
        var folder: String?
    }

    private struct DownloadJob: Codable, Sendable {
        var track: Track
        var fileName: String
        var folderName: String?
    }

    nonisolated private static func job(from task: URLSessionTask) -> DownloadJob? {
        guard let description = task.taskDescription,
              let data = description.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(DownloadJob.self, from: data)
    }

    nonisolated private static func fileSize(at url: URL) -> Int64 {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber else {
            return 0
        }
        return size.int64Value
    }

    nonisolated private static func friendly(_ error: Error) -> String {
        let message = error.localizedDescription
        let lower = message.lowercased()
        if message.contains("429") ||
            lower.contains("rate limit") ||
            lower.contains("recaptcha") {
            return "YouTube is rate-limiting downloads. Try again later."
        }
        if (error as NSError).domain == NSURLErrorDomain {
            return "Network error. Check your connection and try again."
        }
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Download failed" : String(trimmed.prefix(160))
    }
}
