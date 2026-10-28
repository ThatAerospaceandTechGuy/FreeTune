import Foundation

final class BackgroundDownloadService: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    static let identifier = "com.freetune.app.background-downloads"
    static let shared = BackgroundDownloadService()

    private(set) var session: URLSession!

    var onProgress: ((URLSessionDownloadTask, Double) -> Void)?
    var onFinish: ((URLSessionDownloadTask, URL) -> Void)?
    var onError: ((URLSessionTask, Error) -> Void)?

    private override init() {
        super.init()
        let configuration = URLSessionConfiguration.background(withIdentifier: Self.identifier)
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForResource = 60 * 60
        configuration.httpMaximumConnectionsPerHost = 3
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let progress: Double
        if totalBytesExpectedToWrite > 0 {
            progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        } else {
            progress = 0
        }
        onProgress?(downloadTask, progress)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent("freetune-\(UUID().uuidString).download")
        do {
            try FileManager.default.moveItem(at: location, to: staging)
            guard let onFinish else {
                try? FileManager.default.removeItem(at: staging)
                return
            }
            onFinish(downloadTask, staging)
        } catch {
            onError?(downloadTask, error)
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else { return }
        if (error as NSError).code == NSURLErrorCancelled { return }
        onError?(task, error)
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        BackgroundSessionCompletion.shared.complete()
    }
}

final class BackgroundSessionCompletion: @unchecked Sendable {
    static let shared = BackgroundSessionCompletion()

    private var handler: (() -> Void)?

    private init() {}

    func store(_ handler: @escaping () -> Void) {
        self.handler = handler
    }

    func complete() {
        DispatchQueue.main.async {
            let handler = self.handler
            self.handler = nil
            handler?()
        }
    }
}
