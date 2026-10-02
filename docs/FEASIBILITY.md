# Feasibility study: a macOS VM on an M5 iPad Pro

**Status:** Phase 1 deliverable, research only. No code written. Awaiting approval.
**Date of research:** 2 October 2026. Everything below was checked against sources dated 2025–2026; older iPadOS behaviour is called out explicitly where it differs.
**Author:** Claude (research assistant), for a personal, non-commercial experiment.

Legend used throughout: **[V]** verified against the cited primary source · **[U]** unverified, second-hand, or inferred.

---

## 1. Your device and constraints

| Item | Value | Why it matters |
|---|---|---|
| Device | iPad Pro (M5), 256/512 GB → **12 GB RAM** | RAM ceiling for any VM. [V 1] |
| iPadOS | **27.x** (27.0.1 is current, 28 Sep 2026); device shipped on 26.0, build 23A8330; cannot go below 26.0 | Rules out TrollStore, every jailbreak, and the old JIT tricks. [V 2][V 3] |
| Chip security | M5 has SPTM/TXM (all A15+/M2+ chips) and MIE/EMTE | TXM changes how JIT must be enabled (section 5). [V 4][V 5] |
| Computer | Windows PC only, no Mac | Sideloading and pairing must work from Windows. |
| Apple ID | Free (Personal Team) | 7-day signing, 3 apps, 10 App IDs per week, no private entitlements. [V 6] |
| Region | Saudi Arabia (not EU) | No alternative app marketplaces; standard sideloading rules. Having Delta installed does not prove sideloading works: Delta is on the worldwide App Store since 2024. |
| Jailbreak | Not wanted unless unavoidable | No jailbreak exists for M4/M5 iPads or iPadOS 26/27 anyway. [V 7] |

---

## 2. Verdicts at a glance

| Goal | Verdict | The layer that fails | Sources |
|---|---|---|---|
| **1. Boot an ARM64 macOS VM locally on the iPad** | **NO-GO** (non-jailbroken M5). Also NO-GO on a jailbroken M5. Only ever worked on jailbroken M1/M2 iPads on iPadOS ≤ 16.3.1. | Four independent walls: (a) Apple's Virtualization framework is macOS-only; (b) no hypervisor in the iPadOS kernel since 16.4, and the entitlement is private; (c) QEMU's `vmapple` machine needs Apple's hypervisor and Mac-created files; (d) macOS licence allows VM copies only on a device already running macOS. | [V 8][V 9][V 10][V 11][V 12] |
| **2. Steam inside the VM** | **NO-GO** in a macOS guest (no guest). **PARTIAL** in an ARM64 Linux guest: the Steam client can be made to run through an x86 translation layer; actual games are impractical. | No native ARM64 Linux Steam client is published; everything is x86 Steam under FEX/box64, which is then itself emulated by QEMU (emulation on emulation), with no Vulkan guaranteed. | [V 13][V 14][V 15] |
| **3. BeamNG.drive (stress test)** | **NO-GO** locally. Only playable on the iPad by streaming from your Windows PC. | Fails on three layers at once: CPU (x86_64-only binary under FEX under TCG), GPU (needs Vulkan 1.3 with sparse residency, which virtual GPUs lack), RAM (16 GB minimum vs a VM budget of a few GB). | [V 16][V 17] |
| **Enabling layer: an ARM64 Linux VM with JIT and OpenGL acceleration on this iPad** | **GO (plausible, unproven on your exact device)** | Proven by UTM on M-series iPads with JIT via StikDebug. The only M5-specific report on iPadOS 26.0.1 was a crash (UTM 4.7.4) later addressed in 4.7.5; one M5 user on 26.x ran it "just barely usable". | [V 18][V 19][V 20] |

Plain-language summary: **you cannot run macOS on this iPad without changing the hardware or Apple changing the rules.** You *can* run an ARM64 Linux desktop in a VM, at emulated speed, with experimental OpenGL. That is the honest ceiling.

---

## 3. Goal 1 in detail: why an ARM64 macOS guest is blocked

### 3.1 How ARM64 macOS boots as a guest anywhere

Apple-silicon macOS only boots on Apple's own paravirtual platform, exposed by the **Virtualization framework** (`VZMacOSBootLoader`, `VZMacHardwareModel`, `VZMacAuxiliaryStorage`, `VZMacOSRestoreImage`). Apple's documentation lists exactly one platform for the framework, for every macOS-guest class, and for the `com.apple.security.virtualization` entitlement: **macOS**. There is no iOS or iPadOS entry. [V 8]

The guest expects Apple-specific devices (AES engine, `vmapple-cfg`, backdoor interface, Apple paravirtual graphics) and Apple's boot ROM `AVPBooter.vmapple2.bin`, and the install step must be run by `VZMacOSInstaller` on a Mac. [V 10]

### 3.2 Wall 1: no Virtualization framework on iPadOS (technical)

Nothing on the iPad can run Apple's macOS install or boot flow. There is no public or private API to create the hardware model, auxiliary storage or machine identifier a macOS guest needs. **Type:** technical. **UTM solved it?** No. UTM's docs say macOS guests are "supported on Apple Silicon hosts running macOS 12 or higher" and say nothing about iOS. [V 21] **Workaround:** none without copying Apple's private macOS frameworks onto the iPad (see 3.6).

### 3.3 Wall 2: no hypervisor on iPadOS (technical + entitlement + signing)

- Hypervisor.framework is macOS-only API. On iOS the kernel needed the **private** entitlement `com.apple.private.hypervisor`. [V 9]
- UTM documented in October 2023, with a kernel diff, that **Apple removed hypervisor support from the iPadOS kernel in 16.4**. Only M1/M2 iPads on 16.3.1 or lower ever had it, and only with jailbreak or TrollStore. [V 9][V 22]
- UTM's current install table: the sideloadable `UTM.ipa` has **no** hypervisor; only `UTM.deb` (jailbreak) and `UTM-HV.ipa` (TrollStore) do. TrollStore supports iOS 14.0–16.6.1, 16.7 RC and 17.0 only. Your iPad cannot run anything below 26.0. [V 18][V 23]
- A free Apple ID provisioning profile cannot carry private entitlements. [U, standard code-signing behaviour; no single Apple page states it]

Consequence: **everything on this iPad is pure software emulation (QEMU TCG).** There is no "hardware virtualization" to initialize, so the original milestone wording "initialize virtualization backend" would in practice mean "initialize QEMU with JIT".

### 3.4 Wall 3: QEMU's `vmapple` machine cannot help (technical)

QEMU gained a `vmapple` machine type (merged March 2025, QEMU 10.0) that re-implements Apple's paravirtual platform. Its Kconfig says `depends on HVF` (Apple's hypervisor), so it is not even compiled without it; it needs the AVPBooter firmware, aux storage and a root disk produced by Virtualization.framework on a Mac; its only display device wraps Apple's macOS-only ParavirtualizedGraphics framework; and only macOS 12 guests boot. Nobody has reported a TCG port. [V 10]

### 3.5 Wall 4: licensing (legal)

The macOS Tahoe and Sequoia Software License Agreements, section 2.B(iii), allow up to two extra copies "within virtual operating system environments on each Apple-branded computer you own or control **that is already running the Apple Software**" (macOS). An iPad is Apple-branded but is not running macOS, so the plain reading excludes it. Section 2.K forbids copying Apple Boot ROM code or firmware (such as AVPBooter) off a Mac. Section 2.J forbids running macOS on any non-Apple-branded computer, which covers an emulated generic PC. [V 11] This is a legal question, not legal advice; the point is that there is no clean licence path, independent of the technical walls.

**Legitimate installer:** Apple publishes `UniversalMac_<version>_Restore.ipsw` files on its own CDN (`updates.cdn-apple.com`; index at `mesu.apple.com/.../com_apple_macOSIPSW.xml`), the same files Apple Configurator and `VZMacOSRestoreImage.fetchLatestSupported` download. Downloading one is normal. It does not help here, because installing it requires Apple's installer on a Mac. [V 12]

### 3.6 The only place this has worked: jailbroken M1/M2 iPads (labelled: JAILBROKEN PATH)

The 2026 "Virtual Mac" project (nfzerox/VirtualMacOniPad) runs macOS 12 through macOS 26 with Metal acceleration on **jailbroken iPad Pro M1/M2 and iPad Air M1 on iPadOS 14–16.3.1**, by copying Apple's Hypervisor, Virtualization and ParavirtualizedGraphics frameworks from a Mac onto the iPad. Its own README says iPadOS 16.4 and later is blocked because the kernel lost hypervisor support. [V 24] **Cost of this workaround:** a second, older iPad; a jailbreak; copying Apple frameworks (section 2.K problem); no iCloud sign-in in the guest. **Not applicable to an M5.**

### 3.7 Ruled out: x86-64 macOS under emulation (OpenCore route)

UTM does not support macOS guests on iOS; the SLA forbids running macOS on a non-Apple-branded (emulated PC) machine; and users report installs of 14 hours and "too slow to use" even for decade-old Intel macOS versions under TCG. Excluded on licence and on speed. [V 21][V 25]

### 3.8 GPU for a macOS guest: proven vs theoretical

| Path | Status | Evidence |
|---|---|---|
| Apple paravirtual Metal GPU on a Mac host | **Proven** | Apple docs, `VZMacGraphicsDeviceConfiguration`. [V 8] |
| Same, on jailbroken M1/M2 iPad ≤ 16.3.1 via copied frameworks | **Proven (narrow)** | Virtual Mac README. [V 24] |
| QEMU `vmapple` GPU | Mac host only (wraps Apple's black-box framework) | QEMU patch cover letter. [V 10] |
| virtio-gpu / VirGL driver inside a macOS guest | **Does not exist** | Collabora's 2025 virglrenderer status covers Linux guests only. [V 26] |
| Vulkan/MoltenVK/Venus inside a macOS guest | Theoretical, irrelevant without a guest driver | [U, inference] |

---

## 4. Apple restriction catalogue

For each restriction: what is blocked, why, its type, whether UTM solved it, the legitimate workaround, and what the workaround costs.

| # | Restriction | Type | UTM solved it? | Legitimate workaround | Cost |
|---|---|---|---|---|---|
| R1 | Virtualization framework absent on iPadOS → no macOS guest | Technical (Apple ships it for macOS only) | No; UTM never claimed it | None on iPadOS | Goal 1 blocked |
| R2 | Hypervisor removed from iPadOS kernel (16.4+); entitlement private | Technical + entitlement + signing | Only via jailbreak/TrollStore on ≤ 16.3.1 | Use TCG emulation instead | ~10× or worse vs native; no x86 guests in practice |
| R3 | JIT (writable+executable memory) blocked by W^X; on TXM chips a debugger must prepare every code page | Technical (TXM) + entitlement (`get-task-allow` only on development signing) | **Yes**: UTM's QEMU fork implements the iOS 26 breakpoint handshake; StikDebug supplies the debugger | StikDebug on-device + pairing file made once on Windows + LocalDevVPN; redo on every launch | Setup friction; JIT must be re-enabled each launch; Wi-Fi required since 26.4 |
| R4 | `get-task-allow` only in development profiles | Signing | Yes (that is why UTM is sideloaded, not on the App Store) | Free Apple ID development signing via AltStore/SideStore/Sideloadly | 7-day expiry |
| R5 | Free Apple ID: 7-day profiles, 3 apps, 10 App IDs per week | Signing/account policy | N/A | On-device refresh (SideStore or Remote AltServer over LocalDevVPN) or keep PC on LAN; LiveContainer to lift the 3-app cap | Weekly refresh ritual; extensions count as App IDs |
| R6 | Per-app RAM ceiling (jetsam, roughly half of RAM); `increased-memory-limit` entitlement raises it to ~75% | Entitlement | Yes in its entitlements file | AltStore 2.3 preserves the entitlement for free IDs; SideStore 0.7.0 currently drops it (bug #1616) | VM RAM roughly 5–6 GB vs 8–9 GB on a 12 GB iPad [U, extrapolated from iPhone measurements] |
| R7 | macOS SLA: VM copies only on a device already running macOS; no Boot ROM copying | Legal | N/A | None for an iPad host | Goal 1 blocked even if R1–R2 vanished |
| R8 | No TrollStore / no jailbreak for M5 or iPadOS 26/27 | Technical (no public exploit) | N/A | None; do not wait for one | Removes the hypervisor and permasign paths entirely |
| R9 | USB passthrough needs private IOKit entitlements | Entitlement | Only in jailbreak/TrollStore builds | None for sideloaded apps | No USB devices inside the VM |
| R10 | EU-style alternative marketplaces | Policy/regional | N/A | Not available in Saudi Arabia; would not grant JIT anyway (needs paid notarization) | None |

Sources for this table: [V 6][V 9][V 18][V 23][V 27][V 28][V 29][V 30].

---

## 5. Topic findings

### 5.1 UTM, UTM SE, UTM-HV on iPadOS

- **Versions.** Stable **4.7.5** (3 Jan 2026). Beta line **5.0.0–5.0.6** (Jan–Sep 2026); 5.0.6 on 24–27 Sep 2026. QEMU fork pinned at `v10.0.12-utm`. Minimum iOS 15 for the app, iOS 26 for the new helper extension. [V 31][V 32]
- **Three builds.** `UTM.ipa` (sideload, needs a JIT enabler, no hypervisor, no USB). `UTM-HV.ipa` (TrollStore only; hypervisor on M1+ iPads; impossible on your device). `UTM SE` (App Store, id1564628856, v4.7.5): no JIT, threaded interpreter, "9–10× slower than regular UTM"; realistic for DOS, Windows 9x, Alpine. The iOS 26 StikDebug support is "non-SE only". [V 18][V 33][V 34]
- **iOS 26/27 state.** 4.7.3: "iOS 26 breaks the technique that AltJIT and similar tools use to enable JIT." 4.7.4: "Support for StikDebug on iOS 26 (non-SE only)." 5.0.6 fixes the VM toolbar on iOS 26 and 27. On 2 Oct 2026 a user on iPadOS 27.0.1 could not install 5.0.6 through iLoader because of the helper extension's bundle ID; the maintainer suggested stripping the extension; 5.0.5 installs fine. [V 35][V 36][V 37]
- **M5 reports.** Issue #7466: M5 on 26.0.1 with 4.7.4 + StikDebug, every VM hung then crashed; closed without a visible fix; 4.7.5 fixed "VMs failing to start and spinning infinitely". A January 2026 blog by an M5 owner: UTM with JIT via AltStore + StikDebug worked, "just barely usable", VMs killed above ~2–4 GB. [V 19][V 20]
- **GPU in UTM for iOS.** Stack: guest virtio-gpu → virglrenderer → ANGLE (Metal backend) → Metal. OpenGL (ES-level) for Linux guests is **proven on iOS** since 4.1, labelled experimental ("some 3D games may crash"). Vulkan via Venus: 5.0.5/5.0.6 release notes announce "Vulkan 1.3 … on Linux guests with VirtIO Venus drivers in Mesa" without a macOS-only qualifier, and "(iOS) Support DirectX 11 with DXMT" for Windows guests, while `Documentation/Graphics.md` still marks Venus/MoltenVK as "future work". Treat **Vulkan on iOS as claimed, not confirmed**. Windows guests get no GPU acceleration (incomplete virtio-gpu drivers). [V 38][V 39][V 40]
- **What changed by version.** iPadOS 17: debugger-based JIT (StikDebug/AltJIT/SideJITServer). 18.4: JIT locked to the debugger path. 26.0: TXM requires per-app opt-in; only updated apps keep JIT. 26.4: offline/airplane-mode JIT trick removed; lockdownd rejects VPN-path connections, breaking SideStore until fixed. 26.6/27: "only work with a few apps", UTM listed first. [V 4][V 41][V 42]

### 5.2 QEMU on iPadOS and JIT today

- **Why JIT matters.** Without JIT, QEMU must interpret; UTM SE is the interpreter build and is roughly an order of magnitude slower. Even with JIT, TCG is far from native: Linaro measured aarch64-under-TCG about 12× slower than hardware acceleration. x86_64 guests are "very slow, impossible to use"; ARM64 guests are the only sane target. [V 33][V 43][V 44]
- **How JIT is enabled on a TXM device (your M5).** Apple's platform-security guide: SPTM and TXM protect page tables and code signing on A15+/M2+ chips. Developers found `mmap(MAP_JIT)` fails and `mprotect` silently drops execute. The only mechanism left: an attached debugger writes one byte to every 16 KB page of the app's JIT region. The app must cooperate by hitting a breakpoint protocol (`brk #0xf00d` with a command in x16, or UTM's older `brk #0x69`) that StikDebug's scripts (`universal.js`, `legacy.js`) service via `prepare_memory_region`. Calling the breakpoint without the script attached crashes the app. Apps that implement it: UTM, Amethyst, MeloNX, DolphiniOS, Geode, ManicEMU, Flycast, iCube and a few others. [V 4][V 5][V 45][V 46][V 47]
- **Consequence for this project.** Any custom app must implement that protocol or reuse UTM's implementation (in UTM's QEMU fork, `tcg/region.c`). This is the strongest technical reason to fork UTM instead of writing a new frontend.
- **Tooling.** StikDebug 3.1.x runs on-device; needs a pairing file (made once on Windows with iLoader or `idevicepair`), the LocalDevVPN loopback VPN from the App Store, Developer Mode, and an app signed with `get-task-allow`. iOS 26.0+ is "Supported, limited app availability". A community fork "StikDebug27" exists. SideJITServer (Windows) targets iOS 17 and has no iOS 26 notes; AltJIT on Windows is unsupported for 17+; Sideloadly's JIT option is iOS ≤ 16 only. [V 47][V 48][V 49]
- **MIE on M5.** Memory Integrity Enforcement covers the kernel and about 70 Apple processes; for third-party apps it is opt-in. It is not what blocks JIT; TXM is. [V 5]

### 5.3 Apple hypervisor and virtualization APIs on iPad

Covered in 3.2–3.3. Summary: Hypervisor.framework and Virtualization.framework are macOS-only public APIs; iPadOS kernels since 16.4 have no hypervisor code; the entitlement that once worked on jailbroken M1 iPads is private; a free Apple ID cannot obtain it; UTM has not solved it and cannot. [V 8][V 9][V 22]

### 5.4 Sideloading from Windows with a free Apple ID (October 2026)

- **Limits (Apple's membership page):** 10 App IDs per 7 days, 3 devices, 3 apps per device, profiles expire after 7 days. Unchanged in 2025–26. [V 6]
- **Entitlements on a free profile:** `get-task-allow` yes. Increased Memory Limit: Apple grants it; AltStore 2.3 preserves it; SideStore 0.7.0 drops it (open bug, Sep 2026). Extended Virtual Addressing: Apple's capability table lists it for the free tier; one third-party source says paid only; unresolved. JIT and hypervisor entitlements: no tier can request them. [V 27][V 28][V 29]
- **2026 risk:** a wave of "provisioning profile is banned" (0xe8008024 / 0xe8008018) soft-bans on free teams, July–September 2026, reported by a signing vendor and in SideStore/iloader issue trackers. Mitigation: use a dedicated burner Apple ID for sideloading. [U 50]
- **Tools:**
  - **Sideloadly 0.70.1**: iOS 7–26+; vendor says 27 works [U]. Needs iTunes from apple.com (not Microsoft Store). Wi-Fi auto-refresh daemon needs the PC on. Simplest for one IPA. [V 51]
  - **AltStore Classic 2.3** (30 Sep 2026) + **AltServer for Windows 1.7.4** (Mar 2026, fixed 26.4 crash). "Remote AltServer" refreshes on-device over LocalDevVPN. Open iOS 27 bugs: #1751 (anisette machineID), #1803 (pairing). Preserves the memory entitlement. [V 52][V 53]
  - **SideStore 0.7.0 alpha/nightly** (0.6.4 is broken), installed from Windows with **iloader**, refreshes on-device via LocalDevVPN; "shaky" on 27 beta; drops the memory entitlement. Same pairing file feeds StikDebug. [V 54][V 55]
  - **LiveContainer 3.8.0** (Jul 2026) runs on 27 and lifts the 3-app cap. Optional. [U 56]
  - **TrollStore**: impossible (iOS ≤ 17.0). **Enterprise-certificate signing services**: terms-of-service violation with mass revocations; avoid. **Jailbreak**: Dopamine 3.0 (Aug 2026) covers 26.0–26.0.1 on A12/A13 only; nothing for M-series beyond 17.3.1; nothing for 27. [V 23][V 7]
- **Recommendation for you:** Sideloadly for the very first install test (fewest moving parts). Then iloader → SideStore + StikDebug for PC-free refresh and JIT. Switch to AltStore 2.3 if VM RAM becomes the bottleneck and its iOS 27 bugs are closed.
- **Short Windows procedure (full guide comes in Phase 2):** install iTunes from apple.com → connect iPad by USB, tap Trust → on iPad enable Settings › Privacy & Security › Developer Mode (appears after first pairing) → sideload the IPA with your tool → Settings › General › VPN & Device Management › trust your Apple ID profile → install LocalDevVPN from the App Store → create the pairing file with iloader and import it into StikDebug → turn on the VPN, open StikDebug, pick the app, enable JIT. [V 57][V 58]

### 5.5 ARM64 macOS as a guest: technical and licensing

Covered in section 3. Nothing further is possible without a Mac host or an unavailable jailbreak.

### 5.6 GPU acceleration, host = iPad, guest = Linux (the achievable case)

| Path | Status on iOS | Evidence |
|---|---|---|
| Software framebuffer (pixman → Metal blit) | Proven | UTM Graphics.md. [V 38] |
| virtio-gpu-gl + virglrenderer + ANGLE/Metal (OpenGL ES-level) | **Proven, experimental**; some 3D apps crash | UTM 4.1 notes, Graphics.md. [V 38][V 39] |
| Vulkan via Venus (Mesa `virtio` driver) + MoltenVK/KosmicKrisp on host | **Claimed in 5.0.5/5.0.6 betas, unconfirmed on iOS**; KosmicKrisp requires iOS 26 | Release notes/discussions. [V 40] |
| DirectX 11 via DXMT (Windows guests) | Claimed for iOS 16+ in 5.0.5 beta; "Windows 3D driver requires an update not released yet" | 5.0.6 notes. [V 32] |
| GPU passthrough | Impossible (no IOMMU exposure, no hypervisor) | [U, inference] |
| Translation layers inside the guest (box64/FEX + Wine/DXVK) | Run on real ARM hardware; inside TCG they become emulation-on-emulation | [V 14][V 15] |

### 5.7 Steam and BeamNG.drive

- **Steam on macOS:** native Apple-silicon client since June 2025 beta; macOS 12+ required since October 2025. Moot without a macOS guest. [V 59]
- **Steam on ARM64 Linux:** no documented public ARM64 desktop client. Valve's undocumented `steam-arm64` build needs 4K pages, a microVM and FEX. Ubuntu's Steam snap (x86 Steam under FEX) went stable June 2026 on real ARM laptops and boards. Proton 11 ships FEX for the Steam Frame. Inside a TCG guest, FEX's JIT output is itself re-translated by QEMU; expect an order-of-magnitude penalty on top of FEX's own. The Steam client may launch; x86 games will not be playable. [V 13][V 14][V 15]
- **BeamNG.drive:** Windows x86_64 (DirectX 11 or Vulkan); experimental native Linux build is Vulkan 1.3-only and needs sparse residency ("unsupported on many virtual GPUs"); minimum 16 GB RAM and 6 GB VRAM; no macOS version; no ARM build. Physics runs at ~2000 Hz and is single-thread-bound. Even on real ARM hardware it runs only through box64/FEX. [V 16][V 17]
- **What would actually let you play BeamNG on the iPad:** Steam Link (free iOS app, LAN streaming from your Windows PC), Moonlight + Sunshine, or GeForce NOW (BeamNG is in its catalogue). These do not run locally and so do not satisfy Goal 1; they are listed last at your request. [V 60]

### 5.8 Can GitHub Actions build UTM (or a fork) for iOS without paid signing?

**Yes.** UTM's `.github/workflows/build.yml` runs on GitHub-hosted `macos-26` for any owner other than `utmapp`, builds per-platform sysroots (cached), builds `UTM.xcarchive` with `scripts/build_utm.sh`, and the `package-ios` job fake-signs with `ldid` (`scripts/package.sh ipa`) into an **unsigned `UTM.ipa` artifact**. That job runs on `release` or on `workflow_dispatch` with `test_release=true`. No Apple certificate is used on the iOS path; the paid-signing steps exist only in the macOS packaging jobs, which a fork simply does not run. Your sideloading tool re-signs the IPA with your free Apple ID. [V 61][V 62]

Cost and limits: Actions is free for public repositories on standard hosted runners, macOS included. Job limit 6 hours; 5 concurrent macOS jobs; 500 MB artifact storage on the Free plan. Upstream warm-cache release builds take 11–41 minutes; cold sysroot builds have taken 2–3 hours and in some runs over 10 hours (interpreter builds are forced to one CPU). **Risk:** a cold sysroot build hitting the 6-hour limit. **Mitigation:** trim the matrix to `ios`/arm64 only, keep caching, and if needed seed the cache from upstream's published `Sysroot-ios-arm64` artifact. A contributor confirmed a 5.0.6 build succeeded on the hosted `macos-26` runner. [V 63][V 64][V 37]

---

## 6. Fallback ladder (local options first)

1. **ARM64 Linux desktop guest in a UTM fork, JIT via StikDebug, virtio-gpu-gl (OpenGL).** Proven stack. Expect "usable but slow" desktop performance, 5–6 GB guest RAM without the memory entitlement. This is the realistic Goal 1 replacement.
2. **Same guest with Vulkan (Venus).** Only if the 5.0.x beta claim is confirmed on your device. Would open some native ARM64 Linux games.
3. **Native ARM64 Linux games and light OpenGL titles** inside (1)/(2). The nearest realistic "gaming" target: SuperTuxKart-class, emulators of 16-bit consoles, not Steam titles.
4. **Windows 11 ARM64 guest** in the same fork: boots with JIT (reports on M2 iPad Air), no GPU acceleration, Steam only via Microsoft's x86 emulation inside QEMU; a demo, not a gaming target.
5. **Streaming** from your Windows PC: Steam Link, Moonlight + Sunshine, GeForce NOW. Plays Steam and BeamNG on the iPad screen, nothing runs locally.

Not on the ladder: any macOS guest (section 3), x86 macOS emulation (3.7), jailbreak-dependent builds (none exist for your iPad).

---

## 7. Recommended approach

**Fork UTM. Do not write a new frontend on bare QEMU, and do not touch hypervisors.**

Why: UTM already solves every layer that can be solved on this iPad: a QEMU fork with the iOS 26 TXM breakpoint handshake for JIT, the virgl/ANGLE/Metal graphics stack, SPICE display and input, memory-pressure handling, and a CI pipeline that already emits an unsigned IPA on GitHub-hosted macOS runners. A new SwiftUI app around QEMU-as-a-library would have to re-implement all of that before reaching UTM's current state.

Fork changes, in order, each as its own small commit:

1. **CI first.** Trim `build.yml` to the `ios`/arm64 configuration (keep `ios-tci` as a no-JIT fallback build), make `package-ios` runnable from `workflow_dispatch`, upload `UTM.ipa` as an artifact. Prove you can download it and install it before any VM work.
2. **Remove the iOS 26 helper extension** (`com.utmapp.UTM.iOSHelper`) and rename bundle IDs to your prefix. Saves an App ID and avoids the 27.0.1 install bug.
3. **Add a Log screen**, reachable from the first screen: captures the app's `os_log` output and QEMU's stderr, with **Copy** and **Export** buttons. Every later step is debugged from what you paste back.
4. **JIT status on the Log screen**: whether the process is being debugged, whether the TXM handshake ran, how many code pages were prepared.
5. Only then: a pre-configured ARM64 Linux VM.

Rejected alternatives: new frontend over QEMU (months of duplicated work, same walls); QEMU `vmapple` port to TCG (not buildable, needs Mac-created images, licence problem); anything needing hypervisor, TrollStore or jailbreak (unavailable on M5).

---

## 8. Smallest first milestone (proposed replacement for "boot a legitimate guest")

Each step is confirmed only when CI is green **and** you have confirmed it on the device.

- **M1a. Install.** A fork-built IPA from GitHub Actions installs on your iPad through Sideloadly, opens, and shows the Log screen. You paste the log.
- **M1b. JIT.** With StikDebug and LocalDevVPN, the Log screen reports JIT enabled and the TXM handshake completed. You paste the log.
- **M1c. Boot.** A legitimate ARM64 Linux image (Alpine or Debian arm64 ISO, downloaded from the distribution) boots with `virtio-gpu-gl` and its framebuffer appears on screen. You send a screenshot and the log.

The guest in this milestone is **Linux, not macOS**, for the reasons in section 3. If that is not acceptable to you, the honest answer is that Phase 2 should not start.

---

## 9. Open questions (will be resolved only by device tests)

1. Does UTM-with-JIT run reliably on an M5 on iPadOS 27.0.1? Only one positive and one negative report exist, both on 26.0.x.
2. Does StikDebug officially cover 27? Its README lists "26.0+"; the "27 works with a few apps" statement comes from SideStore's docs.
3. How much RAM will a VM get on your 12 GB model with and without the memory entitlement? Only iPhone measurements exist.
4. Is Vulkan (Venus) actually functional in UTM's iOS build?
5. Will a cold sysroot build on a hosted `macos-26` runner finish under 6 hours?
6. Which AltStore/SideStore build is stable on 27.0.1 when Phase 2 starts?

---

## 10. Sources

1. 9to5Mac, M5 iPad Pro RAM/core counts by storage tier — https://9to5mac.com/2025/10/15/psa-m5-ipad-pro-models-come-with-different-ram-and-cpu-core-counts/
2. Wikipedia, iPadOS 27 (release 14 Sep 2026; 27.0.1 on 28 Sep 2026) — https://en.wikipedia.org/wiki/IPadOS_27
3. Wikipedia, iPadOS 26 (26.0 preinstalled on iPad Pro M5, build 23A8330; 26.7.1) — https://en.wikipedia.org/wiki/IPadOS_26
4. Apple Platform Security, Operating system integrity (SPTM/TXM on A15+/M2+) — https://support.apple.com/guide/security/operating-system-integrity-sec8b776536b/web
5. Apple Security Research, Memory Integrity Enforcement — https://security.apple.com/blog/memory-integrity-enforcement/ ; Wikipedia Apple M5 — https://en.wikipedia.org/wiki/Apple_M5
6. Apple, Choosing a Membership (Personal Team limits) — https://developer.apple.com/support/compare-memberships/
7. MacRumors, Dopamine 3.0 (iOS 26.0–26.0.1, A12/A13 only) — https://www.macrumors.com/2026/08/07/ios-26-dopamine-jailbreak/
8. Apple Developer docs, Virtualization framework and macOS guest classes (platforms: macOS only) — https://developer.apple.com/documentation/virtualization ; https://developer.apple.com/documentation/virtualization/vzmacosbootloader ; https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.virtualization
9. UTM on X, "Apple removed Hypervisor support from XNU in iOS 16.4" with kernel diff — https://x.com/UTMapp/status/1708907045314035986 ; UTM discussion #5748 — https://github.com/utmapp/UTM/discussions/5748 ; Zhuowei Zhang on the private hypervisor entitlement — https://worthdoingbadly.com/hv/
10. QEMU docs, VMApple machine — https://www.qemu.org/docs/master/system/arm/vmapple.html ; Kconfig `depends on HVF` — https://raw.githubusercontent.com/qemu/qemu/master/hw/vmapple/Kconfig ; patch cover letter (ParavirtualizedGraphics "black box", macOS hosts only) — https://patchew.org/QEMU/20241110215519.49150-1-phil@philjordan.eu/
11. Apple, macOS Tahoe SLA §2.B(iii), §2.J, §2.K — https://www.apple.com/legal/sla/docs/macOSTahoe.pdf ; macOS Sequoia SLA — https://www.apple.com/legal/sla/docs/macOSSequoia.pdf
12. Mr. Macintosh, Apple-silicon macOS IPSW database (links to Apple's CDN) — https://mrmacintosh.com/apple-silicon-m1-full-macos-restore-ipsw-firmware-files-database/ ; Apple docs, VZMacOSRestoreImage — https://developer.apple.com/documentation/virtualization/vzmacosrestoreimage
13. steam-arm64-nix (Valve's undocumented ARM64 client requirements) — https://github.com/Mr-Banana-Egg/steam-arm64-nix ; SteamOS issue #2192 — https://github.com/ValveSoftware/SteamOS/issues/2192
14. It's FOSS, ARM64 Steam snap goes stable (FEX) — https://itsfoss.com/news/arm64-steam-snap-goes-stable/
15. GamingOnLinux, Proton 11.0-1 beta 3 FEX for ARM64 — https://www.gamingonlinux.com/2026/05/proton-11-0-1-beta-3-brings-fex-upgrades-for-linux-arm64-like-the-steam-frame/
16. Steam store, BeamNG.drive system requirements — https://store.steampowered.com/app/284160/BeamNGdrive/
17. BeamNG docs, Vulkan requirements — https://documentation.beamng.com/support/troubleshooting/vulkan/ ; Linux port FAQ — https://www.beamng.com/threads/linux-port-%E2%80%93-feedback-known-issues-and-faq.86422/ ; Steam Deck/Linux notes — https://documentation.beamng.com/support/troubleshooting/steamdeck_linux/
18. UTM docs, Installation on iOS (build table: JIT/Hypervisor/USB) — https://docs.getutm.app/installation/ios/
19. UTM issue #7466 (iPad Pro M5, iPadOS 26.0.1, VMs crash) — https://github.com/utmapp/UTM/issues/7466 ; 4.7.5 notes — https://github.com/utmapp/UTM/discussions/7558
20. Hackernoon, "iPad Pro M5 as a developer: can I UTM?" — https://hackernoon.com/ipad-pro-m5-as-a-developer-can-i-utm
21. UTM docs, macOS guests (Apple Silicon Mac hosts only) — https://docs.getutm.app/guest-support/macos/
22. UTM on X, "Only 16.3.1 and below supports HV" — https://x.com/UTMapp/status/1729238244871807466
23. TrollStore README (supported versions) — https://github.com/opa334/TrollStore
24. nfzerox, VirtualMacOniPad ("Virtual Mac", jailbroken M1/M2 on ≤ 16.3.1) — https://github.com/nfzerox/VirtualMacOniPad
25. Emaculation forum, Mac OS under UTM on iOS "too slow to use" — https://www.emaculation.com/forum/viewtopic.php?t=11408
26. Collabora, state of graphics virtualization with virglrenderer (Linux guests) — https://www.collabora.com/news-and-blog/blog/2025/01/15/the-state-of-gfx-virtualization-using-virglrenderer/
27. Apple, Supported capabilities (iOS) incl. free-tier column — https://developer.apple.com/help/account/reference/supported-capabilities-ios
28. SideStore issue #1616 (increased-memory-limit dropped for free IDs; AltStore preserves it) — https://github.com/SideStore/SideStore/issues/1616
29. Apple Developer Forums, Increased Memory Limit / Extended Virtual Addressing on iPadOS 18.3 — https://developer.apple.com/forums/thread/777370
30. UTM `scripts/package.sh` (fake entitlements incl. `com.apple.private.hypervisor`, IOKit) — https://raw.githubusercontent.com/utmapp/UTM/main/scripts/package.sh
31. UTM releases (4.7.5 stable; 5.0.x betas) — https://github.com/utmapp/UTM/releases ; release timeline — https://releasealert.dev/github/utmapp/utm
32. UTM v5.0.6 release notes — https://github.com/utmapp/UTM/releases/tag/v5.0.6
33. UTM README (UTM SE threaded interpreter) — https://github.com/utmapp/UTM/blob/main/README.md ; "9–10× slower" — https://docs.thatstel.la/utmfaq/installing-utm/installing-on-nonjailbroken-ios
34. App Store, UTM SE — https://apps.apple.com/us/app/utm-se-retro-pc-emulator/id1564628856
35. UTM v4.7.3 notes ("iOS 26 breaks the technique…") — https://github.com/utmapp/UTM/releases/tag/v4.7.3
36. UTM v4.7.4 notes ("Support for StikDebug on iOS 26 (non-SE only)") — https://github.com/utmapp/UTM/discussions/7409
37. UTM discussion #7909 (5.0.6 install failure on iPadOS 27.0.1; hosted macos-26 build) — https://github.com/utmapp/UTM/discussions/7909
38. UTM `Documentation/Graphics.md` — https://github.com/utmapp/UTM/blob/main/Documentation/Graphics.md
39. UTM docs, v4.1 update (virtio-gpu-gl default, ANGLE Metal on iOS) — https://docs.getutm.app/updates/v4.1/
40. UTM v5.0.5 notes and discussions on Venus/KosmicKrisp/DXMT — https://github.com/utmapp/UTM/releases/tag/v5.0.5 ; https://github.com/utmapp/UTM/discussions/7627 ; https://github.com/utmapp/UTM/discussions/7847
41. SideStore docs, Enabling JIT ("26.6 and 27 only work with a few apps") — https://docs.sidestore.io/docs/advanced/jit
42. PiunikaWeb, iOS 26.4 breaks offline JIT — https://piunikaweb.com/2026/03/26/ios-26-4-may-break-jit-for-sideloaded-apps/ ; iDownloadBlog, iOS 18.4 JIT — https://www.idownloadblog.com/2025/02/23/ios-18-4-jit-blocked-by-apple/
43. Linaro, QEMU performance analysis (TCG ~12× slower) — https://www.linaro.org/blog/qemu-a-tale-of-performance-analysis/
44. heise, Windows 11 ARM on iPad Air M2 with JIT — https://www.heise.de/en/news/Windows-11-for-ARM-runs-perfectly-on-iPad-Air-M2-EU-and-JIT-make-it-possible-10364121.html ; Windows Latest — https://www.windowslatest.com/2025/04/22/dev-runs-windows-11-arm-on-ipad-air-m2-using-utm-with-jit-and-its-decent/
45. Play!-CodeGen PR #34 (iOS 26 TXM JIT mechanics: debugger writes to each 16 KB page) — https://github.com/jpd002/Play--CodeGen/pull/34 ; Provenance iCube issue #11 — https://github.com/Provenance-Emu/iCube/issues/11
46. StikJIT `INTEGRATION.md` (brk #0xf00d protocol) — https://github.com/StikDebug/StikJIT/blob/main/INTEGRATION.md ; `legacy.js`/`universal.js` — https://github.com/StikDebug/StikJIT/tree/main/Resources ; UTM QEMU fork `tcg/region.c` (brk #0x69) — https://raw.githubusercontent.com/utmapp/qemu/v10.0.12-utm/tcg/region.c
47. StikDebug README and site — https://github.com/StikDebug/StikDebug ; https://stikdebug.org/ ; StikDebug27 fork — https://github.com/Xarber/StikDebug27
48. SideJITServer — https://github.com/nythepegasus/SideJITServer ; AltJIT (Windows unsupported for iOS 17) — https://faq.altstore.io/altstore-classic/enabling-jit/altjit.md
49. Sideloadly (JIT ≤ iOS 16) — https://sideloadly.io/index.html
50. builds.io, "provisioning profile is banned" 0xe8008024 — https://builds.io/blog/technologies/ios-technologies/provisioning-profile-banned-iphone-0xe8008024/ ; iloader issues #571, #633 — https://github.com/nab138/iloader/issues/571 ; SideStore #1622 — https://github.com/SideStore/SideStore/issues/1622
51. Sideloadly FAQ — https://sideloadly.io/faq.html
52. AltStore release notes (AltStore 2.3; AltServer 1.7.4) — https://faq.altstore.io/release-notes/altstore ; https://faq.altstore.io/release-notes/altserver ; Windows install guide — https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows.md
53. AltStore issues #1751, #1803 (iOS 27) — https://github.com/altstoreio/AltStore/issues/1751 ; https://github.com/altstoreio/AltStore/issues/1803
54. SideStore releases — https://github.com/SideStore/SideStore/releases ; iloader — https://github.com/nab138/iloader
55. builds.io, iOS 27 beta sideloading status — https://builds.io/blog/technologies/ios-technologies/ios-27-beta-sideloading-broken-fix/
56. LiveContainer — https://github.com/LiveContainer/LiveContainer
57. Apple, Enabling Developer Mode on a device — https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device
58. StikDebug pairing-file guide — https://github.com/StikDebug/StikDebug-Guide/blob/main/pairing_file.md
59. MacRumors, Steam native Apple silicon beta (June 2025) — https://www.macrumors.com/2025/06/13/steam-beta-adds-native-apple-silicon-support/ ; Steam requires macOS 12 from 15 Oct 2025 — https://www.macrumors.com/2025/08/06/steam-client-requires-macos-12-october-15/
60. Steam Link on the App Store — https://apps.apple.com/us/app/steam-link/id1246969117 ; GeForce NOW BeamNG listing — https://geforcenow.cloud/game/beamngdrive
61. UTM `.github/workflows/build.yml` — https://github.com/utmapp/UTM/blob/main/.github/workflows/build.yml
62. UTM `Documentation/iOSDevelopment.md` (unsigned IPA, re-signing with a free account, helper extension on iOS 26) — https://github.com/utmapp/UTM/blob/main/Documentation/iOSDevelopment.md
63. GitHub docs, Actions billing (free for public repos on standard runners) — https://docs.github.com/en/billing/concepts/product-billing/github-actions ; limits — https://docs.github.com/en/actions/reference/limits
64. UTM Actions run history (release runs 11–41 min warm; multi-hour cold) — https://github.com/utmapp/UTM/actions/workflows/build.yml
