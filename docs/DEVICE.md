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
