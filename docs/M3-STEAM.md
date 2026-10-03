# M3 — Steam experiment (x86 Steam client on ARM64 Debian, inside the iPad VM)

**Expectations, honestly:** Steam for Linux is an x86 program. On ARM64 it runs through **FEX**
(an x86→ARM64 translator), which here runs inside QEMU's own ARM64 emulation. That is emulation on
top of emulation, so the Steam client will be **very slow** to start and to use (think tens of
minutes for first start, sluggish UI). Getting the Steam login window and library on screen is the
goal of this step (M3a). Games come after (M3b).

Route: Canonical's **ARM64 Steam snap** (`steam`, arm64 stable 1.0.0.85, core24, strict; promoted
to stable 2026-06), which bundles FEX and the x86 Steam runtime and forwards OpenGL/Vulkan to the
VM's native ARM64 Mesa (virgl / Venus, both confirmed working on this iPad).

## 0. Give the VM more memory

Steam's client (a Chromium-based UI plus the x86 runtime) needs more than 2 GB.

1. Power off the Debian VM (toolbar **⏻ › Power Off**).
2. Press and hold **Debian 13** › **Edit** › **System** › **Memory**: **3072** MB. Save.
3. Close UTM, StikDebug › Enable JIT › UTM › **legacy**, start Debian, log in.

UTM has about 5 GB available on this iPad (12 GB model, free-ID signing). 3 GB for the VM leaves
room for QEMU itself. If iPadOS closes UTM during this experiment, that is the memory ceiling: go
back to 2560 MB and tell me.

## 1. Install snap support (Terminal)

```
sudo apt update && sudo apt install -y snapd
```
then
```
sudo snap install snapd
```
then restart Debian so the snap paths are active:
```
sudo reboot
```
(A reboot inside Debian keeps the same UTM session, so StikDebug does not need to re-attach.)

## 2. Install Steam

Log in again, open Terminal:
```
sudo snap install steam
```
It downloads Steam plus its graphics/runtime snaps (roughly 1–2 GB). Wait until it prints
`steam 1.0.0.85 from Canonical ✓ installed` (or similar).

## 3. Start Steam

```
snap run steam
```
Leave it. The first start downloads and unpacks the Steam runtime (another ~1 GB) and then starts
the x86 client through FEX. **Allow up to an hour**; keep UTM on screen with the charger in.

Take screenshots along the way: the terminal output, and the Steam window if it appears (update
progress bar, login screen, library).

## 4. What to send

- Screenshots of the terminal and any Steam window.
- How long it took to reach each stage (update window, login screen, library).
- If UTM disappears: it was closed by iPadOS for memory. Reopen UTM and send **Settings › Logs ›
  Copy**, and tell me the VM memory setting you used.
- If Steam prints errors and exits: screenshot of the last 30 lines of the terminal.

## If you log in

Steam login inside the VM is your real account; Steam Guard will ask for a code. That is fine for
a personal experiment. Don't start any big game downloads yet: the first game test (M3b) will be a
small one.
