# Project report — what we did, what worked, what didn't, and what to try next

**Period:** 2026-10-02 to 2026-10-12 (report written 2026-11-11).
**Device:** iPad Pro M5 (`iPad17,2`), iPadOS 27.0, 12 GB RAM. Free Apple ID. Windows PC only. No jailbreak.
**Rule used throughout:** "works" means CI is green **and** the user confirmed it on the iPad.
Every claim below is tagged:

- **[device]** confirmed on the real iPad (logs or screenshots from the user).
- **[CI]** the build is green, but not tested on the device.
- **[research]** from documentation or sources, not tested by us.
- **[idea]** a proposal, not tested.

---

## 1. Scorecard

### The three original goals

| # | Goal | Result |
|---|---|---|
| 1 | Boot an ARM64 **macOS** VM on the iPad | **Impossible on this device.** Four independent walls (section 4). The user accepted an ARM64 Linux guest instead. |
| 2 | **Steam** inside the VM | **Not reached.** The Linux route exists on paper (ARM64 Steam snap + FEX). It was never run successfully. |
| 3 | **BeamNG.drive** as a stress test | **Not attempted, and not possible locally** (x86-only game, needs Vulkan 1.3 with sparse binding, needs 16 GB RAM). Streaming from the Windows PC is the realistic way. |

### The chain you actually need, link by link

| Link | State |
|---|---|
| 1. Build an iPad app in CI with no Mac | **Proven [device]** |
| 2. Sideload it from Windows with a free Apple ID | **Proven [device]** |
| 3. Turn on JIT on iPadOS 27 (TXM) | **Proven [device]** |
| 4. Boot a real ARM64 Linux in a VM | **Proven [device]** |
| 5. OpenGL in the VM drawn by the iPad GPU | **Proven [device]**, `glxgears` ~870 FPS |
| 6. Vulkan 1.3 in the VM on the iPad GPU | **Proven [device]**, needed our own fix |
| 7. Steam client window | **Not proven** |
| 8. A game running | **Not proven** |

**5 of 8 links are proven; all of the hard "emulation on emulation" work is in the remaining three.**
Everything up to and including the GPU is further along than the YouTube video that started this
(its author got stuck at JIT, which we solved).

Work done: 26 commits on branch `phase2-m1a-ci`, 10 guides in `docs/`, one iPad app (VMLab), one UTM fork with two
patch series, two CI workflows, one GitHub Releases feed.

---

## 2. Timeline

| Date | Event |
|---|---|
| 2026-10-02 | Phase 1 research: macOS VM = no-go. M1a: app installs. M1b: JIT works. M1c: Alpine Linux boots. M2d: GPU test on Alpine falls back to software, switch to Debian 13, OpenGL works. |
| 2026-10-02 to 10-03 | M2e: Vulkan failed with an out-of-memory error, root-caused to a blocked system call, fixed in CI (39c9361), confirmed working on the device on 10-03. |
| 2026-10-03 | Steam guide written (M3). Last commit before a gap of about a week. |
| Between 10-03 and 10-12 | The apps' 7-day signing expired. All apps were deleted instead of re-signed, so the Debian VM and its disk were lost. |
| 2026-10-12 | Recovery doc, Releases feed, `idevice_pair` doc, Logs fix. Rebuild started: StikDebug, pairing file, UTM fork, new Debian VM. VM showed a black screen at 3072 MB; 2048 MB booted. Debian install was in progress when the session paused. Whether it finished is **not recorded**. |
| 2026-11-11 | This report. |

---

## 3. What worked

### 3.1 Build and install pipeline [device]

- GitHub Actions macOS runners build an unsigned `.ipa`. No Mac, no signing secrets. `ldid` fake-signs, Sideloadly re-signs with the free ID.
- The UTM fork builds in about **5 minutes** (it reuses UTM's prebuilt dependency bundle). Each build is published to GitHub Releases as a plain `.ipa`.
- Sideloadly from Windows installed everything. Installing over an expired app keeps its data.
- Docs: `SIDELOAD-WINDOWS.md`, `REFRESH-AND-RECOVERY.md`.

### 3.2 JIT on iPadOS 27 with a free ID [device]

- StikDebug + LocalDevVPN + a pairing file, no jailbreak.
- Test app VMLab: attach in about 3.8 s, JIT test function returned 42, W^X preserved.
- UTM v5.0.5 needs the **legacy.js** script (not universal). One attach covers one VM start.
- Pairing file: iloader works until Apple's login breaks (error -80045). `idevice_pair` works with no Apple ID.
- Docs: `JIT-STIKDEBUG.md`, `DEVICE.md` (M1b).

### 3.3 Linux guests [device]

- Alpine 3.24 aarch64: kernel 6.18.52, 963 MB RAM, emulated Cortex-A72, 2+ cores (`DEVICE.md` M1c).
- Debian 13.7 arm64 with Xfce: installed, rebooted, logged in, ran GPU tests (`DEVICE.md` M2d).

### 3.4 GPU acceleration [device]

| Test | Result |
|---|---|
| OpenGL | `OpenGL renderer string: virgl`, `glxgears` about **870 FPS** |
| Software comparison (Alpine, no virgl) | `kmscube` on llvmpipe about 42 FPS |
| Vulkan | `Virtio-GPU Venus (Apple M5 GPU)`, Vulkan **1.3.269**, driver `venus` |
| `vkcube` | Cube redraws in every captured frame at 120 fps camera capture (so well above 60 FPS; exact in-guest FPS never read) |

Full path: guest Mesa → virtio-gpu → QEMU virglrenderer → ANGLE (OpenGL) or MoltenVK (Vulkan) → Metal → Apple M5 GPU.

### 3.5 Things we built and can reuse

| Asset | What it is |
|---|---|
| `utm/UPSTREAM` + `utm/patches/` | Pinned UTM v5.0.5 plus patch 0001: in-app **Logs** screen (copy, export, JIT status, memory) |
| `utm/virglrenderer-patches/` + `utm/rebuild_virglrenderer.sh` | Fixes Vulkan (Venus) on sideloaded apps by replacing `shm_open` with a file fallback; rebuilds only that library in CI |
| `.github/workflows/build-utm.yml` | Pinned-source UTM build → `.ipa` → GitHub Release |
| `.github/workflows/build-ios.yml` + `Sources/VMLab/` | Small app that tests JIT and reports device facts (optional now) |
| `docs/` | Install, JIT, VM, GPU, recovery guides and the Phase 1 feasibility study |

---

## 4. What didn't work

### 4.1 Hard walls (will not change)

| Wall | Detail | Source |
|---|---|---|
| macOS guest | Apple's Virtualization framework is macOS-only. iPadOS has had no hypervisor since 16.4 and the entitlement is private. QEMU's `vmapple` machine needs the hypervisor. The macOS licence only allows VM copies on a device already running macOS. | [research] `FEASIBILITY.md` |
| x86 macOS via emulation | Licence forbids it and it would be unusably slow. | [research] |
| BeamNG locally | x86 only; needs Vulkan 1.3 with sparse residency; 16 GB RAM minimum against a few GB of VM. | [research] |

### 4.2 Problems we hit and what happened

| # | Problem | Cause | Outcome |
|---|---|---|---|
| 1 | Developer Mode toggle missing | It only appears after the first pairing/sideload | Explained in `SIDELOAD-WINDOWS.md` |
| 2 | Sideloadly "Start" greyed out | No IPA loaded (the CI artifact is a zip that must be unzipped first) | Explained in `SIDELOAD-WINDOWS.md`; Releases now give a plain `.ipa` |
| 3 | StikDebug black screen | User picked StikDebug itself as the JIT target; also a bad iloader install | Pick the app, reinstall with Sideloadly [device] |
| 4 | UTM wizard order in our guide was wrong | Hardware comes before ISO | Guide corrected |
| 5 | Alpine login loops | Two getty processes race on tty0/tty1 | Use Alt+F2 [device] |
| 6 | **Alpine GPU stayed in software** | Alpine's Mesa has no virgl driver | Switched to Debian 13 |
| 7 | Logs nearly empty | `NSLog` did not reach stderr | Set `CFLOG_FORCE_STDERR`, debug log level (f084327) |
| 8 | **Whole app froze during install** | Log reader wrote back to an undrained stderr | Removed the forwarding (f6ece4a) [device] |
| 9 | Debian installer went back to the menu | ISO still attached | Eject the ISO, then Restart |
| 10 | Return on "Software selection" | Accepts all defaults (GNOME) | Space to tick, Tab to Continue |
| 11 | **Vulkan failed**: `failed to allocate/map ring shmem` | iOS refuses `shm_open` without the App Group entitlement | virglrenderer patch + CI rebuild (39c9361) [device] |
| 12 | **Logs screen flashed then blank** | One huge SwiftUI `Text` | Replaced with a `UITextView` (aff82df) [device] |
| 13 | **All apps and the VM lost** | 7-day free-ID expiry; apps were deleted instead of re-signed | Rebuilt from docs; recovery guide written. The VM was **never backed up** |
| 14 | iloader login error -80045 | Apple sign-in change | `idevice_pair` instead [device] |
| 15 | "Untrusted developer" on StikDebug | New signing identity | Trust in Settings › VPN & Device Management |
| 16 | **VM black screen at 3072 MB** (2026-10-12) | **Unknown.** Changing only memory to 2048 MB fixed it | 2048 MB is the last confirmed-good value |
| 17 | iPad slept during the install, UI looked frozen | Auto-Lock | Keep charger in, Auto-Lock Never |

### 4.3 Never resolved or never done

- **Steam never ran.** The M3 guide (`M3-STEAM.md`) was written but never completed. The reinstall after the wipe came first and the session paused during the Debian install.
- The user mentioned that downloading Steam with 3 GB of memory "just wasn't working". Cause unknown; no logs were captured.
- **We never measured CPU speed** of the emulated machine. This is the biggest missing number (section 7).
- The 3072 MB black screen has no root cause (no log was captured).
- The `increased-memory-limit` entitlement is dropped by Sideloadly's free-ID signing. AltStore reportedly keeps it. Not tried.
- Exact in-guest Vulkan FPS (Mesa overlay layer) was never read.
- No persistence work: no backup of the VM, no snapshot, no prebuilt image.
- Networking works (the installer downloaded packages) but was never benchmarked.

---

## 5. Hard limits discovered on this device

| Limit | Value | Effect |
|---|---|---|
| RAM available to UTM | **~5,080 to 5,100 MB** of 11,524 MB | `increased-memory-limit` is dropped on a free ID |
| VM memory that boots | **2048 MB confirmed**; 3072 MB black-screened once | Plan for 2 GB |
| JIT | Needs StikDebug attach **before every VM start** | Close UTM, StikDebug › Enable JIT › UTM › **legacy**, then ▶ |
| Signing | 7 days, 3 apps, 10 App IDs per week | Re-sign weekly; never delete UTM |
| CPU | Pure software emulation (QEMU TCG, no hypervisor). Guest sees a Cortex-A72 model | x86 programs must be translated on top of this |
| Boot time | Alpine 1–2 min to login. Debian: boot screen, then black for several minutes | Slow feedback loop |
| Debian install | About 1–3 hours under emulation (estimate; the first run hit a freeze that is now fixed) | The installer is the most fragile part |
| Dependency bundle | UTM's prebuilt iOS bundle expires **~2026-12-01** | CI must build dependencies itself afterwards (slow) |
| Build artifacts | Expire after 30 days | Releases do not expire |

---

## 6. Why Steam is the hard part

Steam for Linux is an **x86** program. In this VM it would run as:

```
Steam (x86)  →  FEX translator  →  ARM64 Debian  →  QEMU software emulation  →  iPad CPU
```

That is two layers of CPU emulation. The GPU is not the problem (OpenGL and Vulkan reach the Apple
GPU, which is the good news from M2d/M2e). The **CPU** is. Steam's interface is a Chromium-based
program plus a runtime download of about 1 GB. Without a measurement, the honest expectation is
"the client may start, very slowly; games will not be playable".

The Debian + Xfce + snapd + Steam-snap route in `M3-STEAM.md` is also **heavy**: a 20 GiB disk,
roughly 2 GB of snaps, a full desktop, systemd + snapd, all inside a 2 GB VM. That weight is
what the new approach should remove.

---

## 7. The redo: a lightweight environment that launches Steam (or something like it)

None of this is built or tested. It is a plan with go/no-go gates, so a failure stops early and cheaply.

### 7.1 Principles taken from what went wrong

1. **No installer on the device.** The Debian installer cost hours and caused most of the problems (items 8–10, 17). Build the guest disk in CI and download it.
2. **No desktop.** Boot straight into one program. RAM saved goes to the program.
3. **No snapd.** Fewer moving parts, less disk.
4. **Measure first.** Know the CPU speed before building anything for x86.
5. **Never lose the VM again.** The prebuilt image makes a wipe a 10-minute recovery.
6. **Keep 2048 MB** until a higher value is proven.

### 7.2 Options

| Option | What you get | Cost | Verdict |
|---|---|---|---|
| **A. Stream Steam from the Windows PC** (Steam Link, or Moonlight + Sunshine; GeForce NOW for BeamNG) | Real Steam and real BeamNG on the iPad, full speed, 120 Hz possible | Not local, needs the PC (or an internet service); no VM involved | **Do this in parallel.** Zero sideloading, no JIT, no 7-day expiry, about 15 minutes to set up. It is the only way BeamNG will ever run on this iPad. |
| **B. Slim prebuilt image: native ARM64 app first** | A minimal Debian that boots to one native Linux game or benchmark. Proves the lightweight shape and measures real performance | A few CI workflow iterations | **Recommended first step of the local path** |
| **C. Slim image + FEX + x86 Steam (no snap)** | The Steam client in a minimal guest | Depends entirely on the CPU measurement | **Only after B's gate passes** |
| D. Windows 11 ARM guest + Steam | Windows games via Prism | Needs a Windows ARM image, 4 GB or more of RAM, heavy; DirectX 11 path (DXMT) in UTM 5.0.5 is untested | Not lightweight. Park it. |
| E. Another emulator app (e.g. iSH) | Linux shell, x86 userspace | No GPU, very slow, no Steam | Not useful here |

### 7.3 Recommended local path (B then C)

Reuse the existing UTM fork, virglrenderer patch and Releases feed. Add a new CI job that builds a guest image.

| Step | What | Gate (go / no-go) |
|---|---|---|
| **L0** | In the *current* Debian VM (or Alpine), run a 2-minute CPU benchmark (e.g. `openssl speed sha256` and a single-thread compile) and record the numbers in `DEVICE.md`. | Without this, C is guesswork. If the CPU is more than roughly 50x slower than native, **stop at B** and use option A for Steam. |
| **L1** | CI builds a minimal Debian 13 arm64 disk image (debootstrap, kernel, Xorg or a Wayland kiosk compositor, autologin, no desktop environment) and publishes it to Releases. **[idea]**: an arm64 Linux runner should make this fast; availability on the free tier needs checking. | Boots in UTM at 1024–2048 MB; shows a framebuffer; idle RAM under ~400 MB. |
| **L2** | The image autostarts one native ARM64 program that uses the GPU (e.g. `glxgears`/`vkcube`, then a light game such as SuperTuxKart). | FPS recorded; confirms the GPU path survives the slim image. |
| **L3** | Add FEX (from a FEX rootfs, no snap) and run a trivial x86 program (`uname -m`, `glxinfo` as x86). | Works and runs in a reasonable time. |
| **L4** | Launch the x86 Steam client in a window. | Login screen reached = success. Time to each stage recorded. |
| **L5** | Light game from Steam (small, 2D or low-poly). | Playable, or documented as not. |

Things to verify before L1 (each is a small question, not a blocker):

- How to import an existing `.qcow2` into UTM, or whether to generate a `.utm` package in CI.
- Whether the slim kernel keeps `virtio-gpu` + Venus working (it should; same Debian Mesa).
- Whether FEX can be installed on Debian 13 without building it, or whether an Ubuntu base is better for L3.

### 7.4 Housekeeping before December

- **~2026-12-01:** the upstream dependency bundle expires. Before then, run the build once with the "build sysroot from source" input to fill the CI cache, or save the bundle into a Release. Otherwise a fresh build will take hours.
- Re-sign UTM and StikDebug every 7 days. **Never delete UTM.** Back up any VM worth keeping (VM › Share › iCloud Drive).
- Download the newest `.ipa` from Releases: <https://github.com/ahmedps520-svg/macos/releases>.

---

## 8. Short version

- **Worked:** CI-built app, free-ID sideload, JIT on iPadOS 27, a real ARM64 Linux VM, OpenGL and Vulkan on the Apple GPU.
- **Didn't:** macOS guest (impossible), Steam (never reached), BeamNG (not possible locally), the first VM (lost to the 7-day wipe), 3 GB of VM memory (black screen).
- **Next, in order:** (1) set up Steam Link or Moonlight now for real Steam and BeamNG; (2) benchmark the emulated CPU; (3) build a slim prebuilt image; (4) native GPU program; (5) FEX; (6) Steam.
