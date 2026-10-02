import Foundation
import UIKit

/// Facts about the device and the process that matter for running a VM.
enum SystemInfo {
    struct Snapshot {
        let model: String
        let osVersion: String
        let cpuCount: Int
        let physicalMemoryMB: UInt64
        let availableMemoryMB: UInt64
        let isDebugged: Bool
        let csFlags: UInt32
        let hasGetTaskAllow: Bool
        let hasIncreasedMemoryLimit: Bool
        let hasExtendedVirtualAddressing: Bool
        let hasDynamicCodesigning: Bool
        let jitMmapErrno: Int32
    }

    static func take() -> Snapshot {
        let pi = ProcessInfo.processInfo
        let v = pi.operatingSystemVersion
        return Snapshot(
            model: hardwareModel(),
            osVersion: "\(UIDevice.current.systemName) \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)",
            cpuCount: pi.activeProcessorCount,
            physicalMemoryMB: pi.physicalMemory / 1_048_576,
            availableMemoryMB: vmlab_available_memory() / 1_048_576,
            isDebugged: vmlab_is_debugged(),
            csFlags: vmlab_cs_flags(),
            hasGetTaskAllow: vmlab_has_entitlement("get-task-allow"),
            hasIncreasedMemoryLimit: vmlab_has_entitlement("com.apple.developer.kernel.increased-memory-limit"),
            hasExtendedVirtualAddressing: vmlab_has_entitlement("com.apple.developer.kernel.extended-virtual-addressing"),
            hasDynamicCodesigning: vmlab_has_entitlement("dynamic-codesigning"),
            jitMmapErrno: vmlab_probe_jit_mmap()
        )
    }

    static func snapshotText() -> String {
        let s = take()
        var t = ""
        t += "device: \(s.model), \(s.osVersion), \(s.cpuCount) cores\n"
        t += "memory: physical \(s.physicalMemoryMB) MB, available to this app \(s.availableMemoryMB) MB\n"
        t += "codesign: debugged=\(s.isDebugged) flags=0x\(String(s.csFlags, radix: 16))\n"
        t += "entitlements: get-task-allow=\(s.hasGetTaskAllow) increased-memory-limit=\(s.hasIncreasedMemoryLimit) "
        t += "extended-virtual-addressing=\(s.hasExtendedVirtualAddressing) dynamic-codesigning=\(s.hasDynamicCodesigning)\n"
        t += "jit probe: mmap(MAP_JIT, RWX) -> \(s.jitMmapErrno == 0 ? "ok" : "errno \(s.jitMmapErrno) (\(String(cString: strerror(s.jitMmapErrno))))")\n"
        return t
    }

    static func logSnapshot() {
        for line in snapshotText().split(separator: "\n") {
            LogStore.shared.info(String(line))
        }
    }

    /// e.g. "iPad16,5". Mapped to a marketing name only where we know it.
    static func hardwareModel() -> String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var buf = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &buf, &size, nil, 0)
        return String(cString: buf)
    }
}
