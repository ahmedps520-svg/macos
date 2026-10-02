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
| M1b | JIT enabled via StikDebug, reported in-app | in progress |
| M1c | Boot an ARM64 Linux guest and show its framebuffer | not started |

## Layout

- `project.yml` — XcodeGen spec; the Xcode project is generated on the CI runner.
- `Sources/VMLab/` — the iPad app (SwiftUI): status screen, log capture, copy/export.
- `scripts/package_ipa.sh` — turns the unsigned archive into a fake-signed `.ipa`.
- `.github/workflows/build-ios.yml` — builds `VMLab.ipa` on a macOS runner, no Apple signing.
- `docs/FEASIBILITY.md` — Phase 1 research and verdicts.
- `docs/SIDELOAD-WINDOWS.md` — how to install a build from Windows.
- `docs/DEVICE.md` — facts confirmed from logs on the real iPad.
- `docs/JIT-STIKDEBUG.md` — how to enable JIT with StikDebug (M1b).

Nothing here is confirmed to work until CI is green **and** it has been verified on the device.
