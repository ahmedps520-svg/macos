# macos — experimental VM on an M5 iPad Pro

A personal experiment: run a virtual machine locally on an iPad Pro (M5) running iPadOS 27,
built entirely through GitHub Actions and sideloaded from Windows with a free Apple ID.

The research phase concluded that a **macOS guest is not possible** on this device
(see [docs/FEASIBILITY.md](docs/FEASIBILITY.md)); the realistic target is an **ARM64 Linux
guest** under QEMU with JIT, building on UTM's engine.

## Status

| Milestone | Description | State |
|---|---|---|
| M1a | CI-built IPA installs from Windows, opens to a status/log screen | **done** (confirmed on device 2026-10-02, see docs/DEVICE.md) |
| M1b | JIT enabled via StikDebug, reported in-app | **done** (confirmed on device 2026-10-02, test returned 42) |
| M1c | Boot an ARM64 Linux guest and show its framebuffer | **done** (Alpine 3.24 aarch64 booted in the UTM fork on device 2026-10-02) |
| M2d | GPU: OpenGL in the guest rendered by the iPad GPU (virgl → ANGLE → Metal) | **done** (Debian 13 + `glxinfo`: virgl, `glxgears` ~870 FPS, on device 2026-10-02) |

## Layout

- `project.yml` — XcodeGen spec; the Xcode project is generated on the CI runner.
- `Sources/VMLab/` — the iPad app (SwiftUI): status screen, log capture, copy/export.
- `scripts/package_ipa.sh` — turns the unsigned archive into a fake-signed `.ipa`.
- `.github/workflows/build-ios.yml` — builds `VMLab.ipa` on a macOS runner, no Apple signing.
- `utm/UPSTREAM`, `utm/patches/` — our UTM fork: a pinned upstream UTM commit plus a patch series.
- `.github/workflows/build-utm.yml` — builds the UTM fork into an unsigned `UTM-fork-*.ipa`.
- `docs/FEASIBILITY.md` — Phase 1 research and verdicts.
- `docs/SIDELOAD-WINDOWS.md` — how to install a build from Windows.
- `docs/DEVICE.md` — facts confirmed from logs on the real iPad.
- `docs/JIT-STIKDEBUG.md` — how to enable JIT with StikDebug (M1b).
- `docs/M1C-BOOT-LINUX.md` — install the UTM fork and boot Alpine Linux (M1c).
- `docs/M2-GRAPHICS.md` — first GPU test on Alpine (M2d), and why it fell back to software.
- `docs/M2-DEBIAN.md` — install Debian 13 + Xfce and test GPU acceleration (M2d take 2).

Nothing here is confirmed to work until CI is green **and** it has been verified on the device.

**Next:** later-phase milestones (persistence, networking, memory ceiling, GPU) are proposed
but not started; each will be one small, device-confirmed step.
