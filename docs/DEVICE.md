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

## M1c — 2026-10-02, UTM fork build 393e35e (UTM v5.0.5 + patch 0001)

**A legitimate ARM64 Linux guest boots on this iPad and shows its framebuffer.** Confirmed by
screenshots from the device.

Setup that worked:

| Item | Value |
|---|---|
| App | UTM fork from CI run 37023581198 (pinned upstream v5.0.5 + Logs patch), sideloaded with Sideloadly |
| JIT | StikDebug 3.1.13 › Enable JIT › UTM › **legacy** script (UTM v5.0.5 uses `brk #0x69`; universal.js rejects it) |
| Guest image | `alpine-virt-3.24.2-aarch64.iso` (official, alpinelinux.org) |
| VM | Emulate › Linux, ARM64 (aarch64), default system, 1024 MB, default cores, display output on, OpenGL off, 4 GiB disk, no shared directory |

Output from inside the guest (on `/dev/tty2`):

```
Linux localhost 6.18.52-0-virt #1-Alpine SMP PREEMPT_DYNAMIC 2026-09-15 05:37:48 aarch64 Linux

              total   used   free  shared  buff/cache  available
Mem:            963     51    860      19          52        844
Swap:             0      0      0

processor       : 0
BogoMIPS        : 125.00
Features        : fp asimd evtstrm aes pmull sha1 sha2 crc32 cpuid
CPU implementer : 0x41
CPU architecture: 8
CPU part        : 0xd08
CPU revision    : 3
```

| Fact | Meaning |
|---|---|
| Kernel 6.18.52 `aarch64` | real ARM64 Linux running under QEMU TCG with JIT |
| 963 MB total | the 1024 MB configured, minus kernel reservations |
| CPU part `0xd08` | QEMU's emulated Cortex-A72 model (no hypervisor; pure emulation) |
| ≥2 processors | multi-core TCG works |

Quirk found: the Alpine virt ISO starts a login prompt on both `/dev/tty1` and `/dev/tty0`,
which are the same screen. The two race for keystrokes, so logging in there loops until
"Login timed out after 60 seconds". Switching to console 2 with **Alt+F2** (UTM's on-screen key
row, or Option+F2 on a hardware keyboard) gives a single login, which works.

Conclusion: Phase 2 milestone 1 ("launch app → backend → create ARM64 VM → boot legitimate guest
→ framebuffer on the iPad") is **done** on iPad17,2 / iPadOS 27.0, with the guest being Linux
(macOS is not possible on this device; see FEASIBILITY.md).

## M2d — 2026-10-02, UTM fork build f6ece4a, Debian 13.7 arm64

**OpenGL GPU acceleration works on this iPad.** Reported by the user from the device.

| Item | Value |
|---|---|
| Guest | Debian 13.7 ("trixie") arm64, installed from `debian-13.7.0-arm64-netinst.iso` |
| VM | Emulate › Linux, ARM64, 2048 MB, display card `virtio-gpu-gl-pci` (OpenGL acceleration on), 20 GiB disk |
| UTM settings | Renderer Backend default (ANGLE Metal), Vulkan Driver default |
| `glxinfo -B` | `OpenGL renderer string: virgl (...)` |
| `glxgears` | about **870 FPS** average |
| Comparison | Alpine with software rendering: `kmscube` on llvmpipe at ~42 FPS (different test; rough comparison only) |

Path confirmed end to end: guest Mesa virgl → virtio-gpu → QEMU virglrenderer → ANGLE → Metal → iPad GPU.

Notes from this run:
- The first build with full log capture (f084327) froze the whole app near the end of the
  install. f6ece4a removed the log reader's blocking write to the debugger-launched process's
  original stderr; the install, reboot and GPU test then ran without a freeze.
- After "Installation complete", the VM rebooted into the installer again because the ISO was
  still attached. Ejecting it from the toolbar's disc menu and using the toolbar's Restart
  (third button) booted the installed system. The first boot shows Debian's boot screen, then
  black for a few minutes, then the login screen.
- Pressing Return on the installer's Software selection screen accepts the defaults (GNOME).
