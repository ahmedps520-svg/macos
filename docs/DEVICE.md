# Device facts (confirmed from VMLab logs)

Updated as each milestone is confirmed on the real iPad.

## M1a — 2026-10-02, build f567dd3 (installed with Sideloadly, free Apple ID)

| Fact | Value | Meaning |
|---|---|---|
| Hardware | `iPad17,2` | iPad Pro (M5), 9-core CPU model (256/512 GB) |
| OS | iPadOS 27.0.0 | current major release |
| Physical RAM | 11,524 MB | the 12 GB model |
| RAM available to the app | ~5,100 MB | jetsam ceiling without the memory entitlement |
| `get-task-allow` | true | debugger/JIT tools can attach |
| `increased-memory-limit` | **false** | Sideloadly's free-ID signing did not keep it. To raise the ceiling later: try AltStore 2.3, which preserves it |
| `extended-virtual-addressing` | false | not requested |
| `dynamic-codesigning` | false | expected; no tier can request it |
| Code-signing flags | `0x22003305` | `CS_DEBUGGED` (0x10000000) not set: no debugger yet |
| `mmap(MAP_JIT, RWX)` | errno 1, Operation not permitted | expected on a TXM device before a debugger prepares memory |

Conclusion: the free-ID sideload pipeline from Windows works on this iPad. JIT is the next
gate (M1b).

## M1b — 2026-10-02, build 9807e11 (StikDebug 3.1.13, LocalDevVPN, universal script)

JIT works on this device. Log excerpt:

```
17:48:09.910 JIT: opening stikdebug://enable-jit?bundle-id=dev.ahmedps520.vmlab.7N75CWF776&pid=996&script-name=universal.js
17:48:09.946 JIT: UIApplication.open returned true
17:48:13.785 JIT: CS_DEBUGGED set (flags 0x32003005)
17:48:14.313 JIT: creating 16 MiB split region, breakpoints=true
17:48:14.370 JIT: region step=done err=0 rw=0x1158b4000 rx=0x1168b4000
17:48:14.370 JIT: sending JIT26Detach
17:48:14.374 JIT: test function returned 42 (expected 42)
17:48:14.374 JIT: READY. debugged=true flags=0x32003005
```

| Fact | Value | Meaning |
|---|---|---|
| Attach time | ~3.8 s from tapping the button to `CS_DEBUGGED` | StikDebug URL-scheme path works on iPadOS 27.0 |
| Handshake | `brk #0xf00d` prepare-region + detach, 16 MiB region, ~60 ms | the universal-script protocol (same as UTM's QEMU fork) is accepted by TXM on M5 |
| Execution | code written via RW alias, executed via RX alias, returned 42 | real JIT, W^X preserved |
| `mmap(MAP_JIT, RWX)` | still errno 1 | expected: on TXM only the split-alias + debugger path works |
| Bundle ID | Sideloadly renamed it to `dev.ahmedps520.vmlab.7N75CWF776` | the app reads its own bundle ID at runtime, so the URL is correct |
| Pitfalls seen | choosing StikDebug itself as the JIT target freezes StikDebug (black screen); a StikDebug installed via iloader showed the same symptom until reinstalled via Sideloadly | documented for future setups |

Conclusion: the full chain (free Apple ID → Sideloadly → StikDebug + LocalDevVPN → iOS 26
TXM handshake) works on iPad17,2 / iPadOS 27.0. Next gate: M1c, booting a guest.
