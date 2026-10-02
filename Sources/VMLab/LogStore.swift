import Foundation
import OSLog
import SwiftUI
import UniformTypeIdentifiers

/// Single in-memory log for the whole app. Captures our own messages and everything any
/// library prints to stdout/stderr, so a copied log contains QEMU output later on.
final class LogStore: ObservableObject {
    static let shared = LogStore()

    @Published private(set) var text: String = ""

    private let osLog = Logger(subsystem: "dev.ahmedps520.vmlab", category: "app")
    private let queue = DispatchQueue(label: "vmlab.log", qos: .utility)
    private var started = false
    private var pipe: Pipe?
    private let maxBytes = 2_000_000

    private static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private init() {}

    func start() {
        guard !started else { return }
        started = true
        captureStandardStreams()
    }

    func info(_ message: String) { append(level: "INFO", message); osLog.info("\(message, privacy: .public)") }
    func warn(_ message: String) { append(level: "WARN", message); osLog.warning("\(message, privacy: .public)") }
    func error(_ message: String) { append(level: "ERROR", message); osLog.error("\(message, privacy: .public)") }

    func clear() {
        DispatchQueue.main.async { self.text = "" }
    }

    /// Full log plus a header, suitable for pasting.
    func export() -> String {
        var out = "VMLab log export\n"
        out += "\(BuildInfo.summary)\n"
        out += SystemInfo.snapshotText()
        out += "\n----- log -----\n"
        out += text
        return out
    }

    private func append(level: String, _ message: String) {
        let line = "\(Self.stamp.string(from: Date())) [\(level)] \(message)\n"
        appendRaw(line)
    }

    private func appendRaw(_ line: String) {
        DispatchQueue.main.async {
            self.text.append(line)
            if self.text.utf8.count > self.maxBytes {
                self.text = String(self.text.suffix(self.maxBytes / 2))
            }
        }
    }

    /// Redirect stdout and stderr into the log. Lines are prefixed so they can be told apart.
    private func captureStandardStreams() {
        let pipe = Pipe()
        self.pipe = pipe
        setvbuf(stdout, nil, _IOLBF, 0)
        setvbuf(stderr, nil, _IONBF, 0)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDERR_FILENO)
        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { [weak self] h in
            let data = h.availableData
            guard !data.isEmpty, let self else { return }
            let chunk = String(decoding: data, as: UTF8.self)
            for line in chunk.split(separator: "\n", omittingEmptySubsequences: true) {
                self.appendRaw("\(Self.stamp.string(from: Date())) [stdio] \(line)\n")
            }
        }
    }
}

/// Lets the Export button hand the log to the share sheet as a .txt file.
struct LogFile: Transferable {
    let contents: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .plainText) { item in
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("VMLab-log-\(Int(Date().timeIntervalSince1970)).txt")
            try item.contents.write(to: url, atomically: true, encoding: .utf8)
            return SentTransferredFile(url)
        }
    }
}
