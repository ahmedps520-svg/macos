import SwiftUI

@main
struct VMLabApp: App {
    @StateObject private var log = LogStore.shared

    init() {
        LogStore.shared.start()
        LogStore.shared.info("VMLab started. \(BuildInfo.summary)")
        SystemInfo.logSnapshot()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(log)
        }
    }
}
