import Foundation

enum BuildInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    }
    static var gitSHA: String {
        Bundle.main.object(forInfoDictionaryKey: "VMLabGitSHA") as? String ?? "unknown"
    }
    static var buildDate: String {
        Bundle.main.object(forInfoDictionaryKey: "VMLabBuildDate") as? String ?? "unknown"
    }
    static var bundleID: String {
        Bundle.main.bundleIdentifier ?? "?"
    }
    static var summary: String {
        "version \(version) (\(build)), commit \(gitSHA), built \(buildDate), bundle \(bundleID)"
    }
}
