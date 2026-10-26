import Foundation
import Network
import CryptoKit
import Observation

/*
 * The voice pack (UX upgrades 26 Oct 2026, section 9): the offline speech model, downloaded once on first use over
 * Wi-Fi only (never over mobile data or Low Data Mode), then kept on the phone. The engine is whisper.cpp (its official
 * XCFramework, Packages/WhisperBin); the model is its multilingual "base" model, 5-bit (about 57 MB, Uzbek and Russian
 * in one pack), from the whisper.cpp project's own Hugging Face page, pinned to one version and checked by its SHA-256.
 * Vosk was the first choice, but its iOS library is only given on request, so it cannot be built in CI.
 */
@Observable
final class VoicePack {
    static let shared = VoicePack()

    enum PackState: Equatable { case none, loading, ready, failed }
    private(set) var state: PackState = .none
    /// 0…1 while loading.
    private(set) var progress: Double = 0
    /// The phone is on Wi-Fi (or Ethernet): not a costly or limited link.
    private(set) var wifi = false

    static let modelURL = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/5359861c739e955e79d9a303bcbc70fb988958b1/ggml-base-q5_1.bin")!
    static let modelSHA = "422f1ae452ade6f30a004d7e5c6a43195e4433bc370bf23fac9cc591f01a8898"
    static let modelMB = 57

    @ObservationIgnored private let monitor = NWPathMonitor()
    @ObservationIgnored private var session: URLSession?
    @ObservationIgnored private var task: URLSessionDownloadTask?
    @ObservationIgnored private let loader = PackLoader()

    /// Where the model is kept (Application Support, not backed up to iCloud).
    static var file: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("voice", isDirectory: true)
        return base.appendingPathComponent("ggml-base-q5_1.bin")
    }

    private init() {
        loader.pack = self
        state = FileManager.default.fileExists(atPath: VoicePack.file.path) ? .ready : .none
        monitor.pathUpdateHandler = { [weak self] path in
            let ok = path.status == .satisfied && !path.isExpensive && !path.isConstrained
            DispatchQueue.main.async { self?.wifi = ok }
        }
        monitor.start(queue: DispatchQueue(label: "metrx.voice.net"))
    }

    /// Starts the download (Wi-Fi only); false when there is no Wi-Fi now.
    @discardableResult func download() -> Bool {
        if state == .ready || state == .loading { return true }
        guard wifi else { return false }
        let cfg = URLSessionConfiguration.default
        // never over mobile data or Low Data Mode, even if the phone switches while it loads
        cfg.allowsCellularAccess = false
        cfg.allowsExpensiveNetworkAccess = false
        cfg.allowsConstrainedNetworkAccess = false
        cfg.timeoutIntervalForResource = 60 * 30
        let s = URLSession(configuration: cfg, delegate: loader, delegateQueue: OperationQueue.main)
        session = s
        progress = 0
        state = .loading
        let t = s.downloadTask(with: VoicePack.modelURL)
        task = t
        t.resume()
        return true
    }

    func cancel() { task?.cancel(); task = nil; if state == .loading { state = .none } }

    /// Deletes the pack (Profile).
    func remove() {
        cancel()
        try? FileManager.default.removeItem(at: VoicePack.file)
        VoiceEngine.shared.unload()
        state = .none
    }

    fileprivate func wrote(_ done: Int64, _ total: Int64) {
        let t = total > 0 ? Double(total) : Double(VoicePack.modelMB) * 1_048_576
        progress = min(1, Double(done) / t)
    }

    fileprivate func finished(_ location: URL) {
        // the file must be moved before this returns
        let fm = FileManager.default
        let dest = VoicePack.file
        do {
            guard VoicePack.sha256(location) == VoicePack.modelSHA else { throw URLError(.cannotDecodeContentData) }
            try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            var dir = dest.deletingLastPathComponent()
            var rv = URLResourceValues(); rv.isExcludedFromBackup = true
            try? dir.setResourceValues(rv)
            try? fm.removeItem(at: dest)
            try fm.moveItem(at: location, to: dest)
            state = .ready
            progress = 1
            Haptic.confirm()
            AppModel.shared.say("ux.vReady")
        } catch {
            state = .failed
            AppModel.shared.say("ux.vFail", kind: .error)
        }
    }

    fileprivate func failed(_ error: Error) {
        if (error as NSError).code == NSURLErrorCancelled { return }
        if state == .ready { return }
        state = .failed
        AppModel.shared.say("ux.vFail", kind: .error)
    }

    /// The file's SHA-256, read in pieces.
    static func sha256(_ url: URL) -> String? {
        guard let h = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? h.close() }
        var hasher = SHA256()
        while true {
            let d = (try? h.read(upToCount: 1 << 20)) ?? nil
            guard let d, !d.isEmpty else { break }
            hasher.update(data: d)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

/// The download's delegate (URLSession wants an NSObject): it hands everything to the pack, on the main queue.
private final class PackLoader: NSObject, URLSessionDownloadDelegate {
    weak var pack: VoicePack?
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        pack?.wrote(totalBytesWritten, totalBytesExpectedToWrite)
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        pack?.finished(location)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { pack?.failed(error) }
        session.finishTasksAndInvalidate()
    }
}
