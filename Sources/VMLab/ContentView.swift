import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var log: LogStore
    @StateObject private var jit = JITManager.shared
    @State private var snapshot = SystemInfo.take()
    @State private var copied = false

    var body: some View {
        NavigationStack {
            List {
                Section("Build") {
                    row("Version", "\(BuildInfo.version) (\(BuildInfo.build))")
                    row("Commit", BuildInfo.gitSHA)
                    row("Built", BuildInfo.buildDate)
                    row("Bundle ID", BuildInfo.bundleID)
                }
                Section("Device") {
                    row("Model", snapshot.model)
                    row("System", snapshot.osVersion)
                    row("CPU cores", "\(snapshot.cpuCount)")
                    row("Physical RAM", "\(snapshot.physicalMemoryMB) MB")
                    row("Available to app", "\(snapshot.availableMemoryMB) MB")
                }
                Section("JIT readiness") {
                    flag("Debugger attached (CS_DEBUGGED)", snapshot.isDebugged)
                    flag("get-task-allow entitlement", snapshot.hasGetTaskAllow)
                    flag("increased-memory-limit entitlement", snapshot.hasIncreasedMemoryLimit)
                    flag("extended-virtual-addressing", snapshot.hasExtendedVirtualAddressing)
                    row("mmap(MAP_JIT) probe", snapshot.jitMmapErrno == 0 ? "ok" : "fails, errno \(snapshot.jitMmapErrno)")
                    Button("Refresh") {
                        snapshot = SystemInfo.take()
                        SystemInfo.logSnapshot()
                    }
                }
                Section {
                    row("State", jit.state.label)
                    Button("Enable JIT with StikDebug") { jit.enableViaStikDebug() }
                        .disabled(isBusy)
                    Button("Wait for debugger (manual attach)") { jit.waitForDebuggerManually() }
                        .disabled(isBusy)
                    if isBusy {
                        Button("Cancel", role: .cancel) { jit.cancel() }
                    }
                } header: {
                    Text("JIT (M1b)")
                } footer: {
                    Text("Needs StikDebug + LocalDevVPN installed and the VPN on. \"Enable JIT with StikDebug\" opens StikDebug with the universal script. If that does not work, press \"Wait for debugger\", switch to StikDebug, choose VMLab and the universal script. The app will crash if a debugger attaches WITHOUT the universal script.")
                }
                Section {
                    NavigationLink("Open log") { LogView() }
                    Button(copied ? "Copied" : "Copy full log") {
                        UIPasteboard.general.string = log.export()
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                    }
                    ShareLink(item: LogFile(contents: log.export()), preview: SharePreview("VMLab log")) {
                        Text("Export log as file")
                    }
                } header: {
                    Text("Logs")
                } footer: {
                    Text("Copy or export the log and paste it back into the chat. Milestone M1a is done when this screen is visible on the iPad.")
                }
            }
            .navigationTitle("VMLab")
        }
    }

    private var isBusy: Bool {
        switch jit.state {
        case .waitingForDebugger, .debuggerAttached, .preparing: return true
        default: return false
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary).textSelection(.enabled)
        }
    }

    private func flag(_ label: String, _ on: Bool) -> some View {
        HStack {
            Text(label)
            Spacer()
            Image(systemName: on ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(on ? Color.green : Color.secondary)
        }
    }
}

struct LogView: View {
    @EnvironmentObject private var log: LogStore

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(log.text.isEmpty ? "(empty)" : log.text)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                Color.clear.frame(height: 1).id("bottom")
            }
            .onChange(of: log.text) { _, _ in
                withAnimation { proxy.scrollTo("bottom") }
            }
        }
        .navigationTitle("Log")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Copy") { UIPasteboard.general.string = log.export() }
                ShareLink(item: LogFile(contents: log.export()), preview: SharePreview("VMLab log")) {
                    Image(systemName: "square.and.arrow.up")
                }
                Button("Clear", role: .destructive) { log.clear() }
            }
        }
    }
}
