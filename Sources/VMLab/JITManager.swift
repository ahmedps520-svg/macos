import Foundation
import UIKit

/// Drives JIT acquisition on iOS 26+ with TXM: ask StikDebug to attach, wait for
/// CS_DEBUGGED, run the region handshake, prove execution, detach.
@MainActor
final class JITManager: ObservableObject {
    enum State: Equatable {
        case idle
        case waitingForDebugger(secondsLeft: Int)
        case debuggerAttached
        case preparing
        case ready(testResult: Int)
        case failed(String)

        var label: String {
            switch self {
            case .idle: return "not enabled"
            case .waitingForDebugger(let s): return "waiting for debugger (\(s)s)"
            case .debuggerAttached: return "debugger attached"
            case .preparing: return "preparing JIT region"
            case .ready(let r): return r == 42 ? "JIT ready (test returned 42)" : "region prepared, test returned \(r)"
            case .failed(let why): return "failed: \(why)"
            }
        }
        var isReady: Bool { if case .ready(42) = self { return true } else { return false } }
    }

    static let shared = JITManager()

    @Published private(set) var state: State = .idle
    @Published private(set) var region: vmlab_jit_region_t?

    private let log = LogStore.shared
    private var pollTask: Task<Void, Never>?
    /// 16 MiB is enough to prove the mechanism; QEMU will size its own buffer later.
    private let testRegionSize = 16 * 1024 * 1024

    private init() {}

    /// True on iOS 26+ (TXM/SPTM enforcement on M2+/A15+). Used to decide whether a script
    /// must be requested from StikDebug and whether the breakpoint protocol is required.
    var requiresScriptProtocol: Bool {
        if #available(iOS 26, *) { return true }
        return false
    }

    var stikDebugURL: URL? {
        var c = URLComponents()
        c.scheme = "stikdebug"
        c.host = "enable-jit"
        var items = [
            URLQueryItem(name: "bundle-id", value: Bundle.main.bundleIdentifier ?? ""),
            URLQueryItem(name: "pid", value: String(getpid())),
        ]
        if requiresScriptProtocol {
            items.append(URLQueryItem(name: "script-name", value: "universal.js"))
        }
        c.queryItems = items
        return c.url
    }

    var canOpenStikDebug: Bool {
        guard let url = stikDebugURL else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    /// Open StikDebug via URL scheme, then wait for it to attach.
    func enableViaStikDebug() {
        guard vmlab_has_entitlement("get-task-allow") else {
            fail("this install lacks get-task-allow; re-sideload with a development profile")
            return
        }
        guard let url = stikDebugURL else { fail("could not build stikdebug:// URL"); return }
        log.info("JIT: opening \(url.absoluteString)")
        UIApplication.shared.open(url, options: [:]) { ok in
            Task { @MainActor in
                self.log.info("JIT: UIApplication.open returned \(ok)")
                if !ok {
                    self.fail("iPadOS refused to open StikDebug. Is StikDebug installed?")
                } else {
                    self.waitForDebugger(timeout: 90)
                }
            }
        }
    }

    /// Do not open anything; the user attaches from StikDebug manually (pick VMLab, universal script).
    func waitForDebuggerManually() {
        guard vmlab_has_entitlement("get-task-allow") else {
            fail("this install lacks get-task-allow; re-sideload with a development profile")
            return
        }
        log.info("JIT: waiting for an external debugger (attach from StikDebug with the universal script)")
        waitForDebugger(timeout: 180)
    }

    func cancel() {
        pollTask?.cancel()
        pollTask = nil
        if case .waitingForDebugger = state { state = .idle }
    }

    private func waitForDebugger(timeout: Int) {
        pollTask?.cancel()
        state = .waitingForDebugger(secondsLeft: timeout)
        pollTask = Task { @MainActor in
            var left = timeout
            while !Task.isCancelled {
                if vmlab_is_debugged() {
                    log.info("JIT: CS_DEBUGGED set (flags 0x\(String(vmlab_cs_flags(), radix: 16)))")
                    state = .debuggerAttached
                    // Give the script a moment to reach its breakpoint loop.
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    runHandshake()
                    return
                }
                if left <= 0 {
                    fail("no debugger attached within \(timeout)s")
                    return
                }
                if left % 5 == 0 { state = .waitingForDebugger(secondsLeft: left) }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                left -= 1
            }
        }
    }

    private func runHandshake() {
        state = .preparing
        let useBrk = requiresScriptProtocol
        log.info("JIT: creating \(testRegionSize / 1_048_576) MiB split region, breakpoints=\(useBrk)")
        var r = vmlab_jit_region_create(testRegionSize, useBrk)
        log.info("JIT: region step=\(String(cString: vmlab_jit_step_name(r.step))) err=\(r.err) rw=0x\(String(r.rw, radix: 16)) rx=0x\(String(r.rx, radix: 16))")
        guard r.err == 0, String(cString: vmlab_jit_step_name(r.step)) == "done" else {
            let why = "region setup failed at \(String(cString: vmlab_jit_step_name(r.step))) (\(r.err): \(String(cString: strerror(r.err))))"
            if useBrk { vmlab_jit26_detach() }
            fail(why)
            return
        }
        if useBrk {
            log.info("JIT: sending JIT26Detach")
            vmlab_jit26_detach()
        }
        log.info("JIT: writing test code through RW alias and calling through RX alias")
        let result = vmlab_jit_region_test(&r)
        log.info("JIT: test function returned \(result) (expected 42)")
        region = r
        state = .ready(testResult: Int(result))
        if result == 42 {
            log.info("JIT: READY. debugged=\(vmlab_is_debugged()) flags=0x\(String(vmlab_cs_flags(), radix: 16))")
        } else {
            log.warn("JIT: unexpected test result \(result)")
        }
    }

    private func fail(_ why: String) {
        log.error("JIT: \(why)")
        state = .failed(why)
    }
}
