# M2d (take 2) — Debian 13 desktop with GPU acceleration

Alpine's Mesa leaves out the virgl OpenGL driver, so GPU acceleration can't work there.
Debian 13 ("trixie") includes it. Goal: install Debian 13 with the light **Xfce** desktop in the
UTM fork, then confirm OpenGL is drawn by the iPad GPU:

```
OpenGL renderer string: virgl (... ANGLE ... Metal ... Apple ...)
```

Expect **1–3 hours**, mostly the installer downloading and unpacking packages under emulation.
You can leave it running, but follow "Before you start".

## Before you start

- **Install the newest UTM fork build** (Actions › Build UTM fork (iOS) › newest green run ›
  `UTM-fork-ipa-…`) with Sideloadly. It replaces the old UTM and keeps your VMs. This build's
  Logs screen also captures UTM's and QEMU's messages, which the previous one missed.
- **Keep the iPad awake and UTM in front.** iPadOS freezes apps in the background, which pauses
  the VM. Plug in the charger, and set Settings › Display & Brightness › **Auto-Lock › Never**
  for the duration (set it back afterwards).
- Wi-Fi on (the installer downloads about 1 GB).

## 1. Download Debian (iPad, Safari)

<https://cdimage.debian.org/debian-cd/current/arm64/iso-cd/debian-13.7.0-arm64-netinst.iso>

About 700 MB, saved to Files › Downloads. Official Debian image.

## 2. Create the VM

Start UTM through StikDebug first (Enable JIT › UTM › **legacy**). Then:

1. **+** › **Emulate** › **Linux**.
2. **Hardware**:
   - Architecture **ARM64 (aarch64)**, System default.
   - Memory **2048 MB**.
   - CPU Cores: default.
   - **Enable display output: on.**
   - **Enable hardware OpenGL acceleration: on** (this time we want it).
   Next.
3. **Linux**: Boot from ISO image › Browse › `debian-13.7.0-arm64-netinst.iso`. Next.
4. **Storage**: **20** GiB (only the space actually used is taken from the iPad). Next.
5. **Shared Directory**: leave empty. Next.
6. **Summary**: name **Debian 13**. Save.
7. Tap **Debian 13** › **▶**.

## 3. Install Debian

A blue/grey menu appears. Choose **Install** (not "Graphical install"; the text one is faster
here) and press Return. Use arrow keys, Space to tick boxes, Tab to move to buttons, Return to
confirm. UTM's key row has the arrow keys and Tab.

| Installer screen | Choose |
|---|---|
| Language | English |
| Location | other › Asia › **Saudi Arabia** |
| Locale | **en_US.UTF-8** |
| Keyboard | **American English** |
| Hostname | `debian` (default is fine) |
| Domain name | leave empty |
| Root password | **leave both empty** (this gives your user `sudo` instead) |
| Full name / username | your choice, e.g. `ahmed` |
| User password | choose one and **write it down** |
| Partitioning | **Guided – use entire disk** › the 20 GB disk › **All files in one partition** › **Finish partitioning…** › **Yes** |
| Package manager mirror | Saudi Arabia (or **deb.debian.org**) › proxy empty |
| Popularity contest | No |
| **Software selection** | Untick **GNOME**. Tick **Xfce**. Keep **Debian desktop environment** and **standard system utilities** ticked. Continue |

The "Installing software" step is the long one (could be an hour or more). Leave it.

**At "Installation complete":** before pressing Continue, tap the VM toolbar's **disc** icon and
**eject** the Debian ISO so the VM boots from the disk next time. Then press **Continue**. The
VM reboots by itself (this is a reboot inside the VM, so StikDebug does not need to re-attach).

## 4. First boot

You should get a graphical login screen. Log in with your username and password. You are now on
the Xfce desktop.

If the screen stays black for more than 5 minutes after the reboot, tap the VM toolbar
**Display** button and check the options; then send Logs.

## 5. GPU test

Open **Applications › Terminal Emulator** (top-left menu) and type:

```
sudo apt install -y mesa-utils
```

(enter your user password when asked), then:

```
glxinfo -B
```

Take a **screenshot**. The key line is **`OpenGL renderer string:`**.

Then:

```
glxgears
```

Watch for 10 seconds, note the FPS numbers it prints in the terminal, close the gears window.

## 6. Send the results

- Screenshot of `glxinfo -B`.
- The `glxgears` FPS numbers.
- UTM **Settings › Logs › Copy** (open a second UTM window with the VM toolbar's **Display ›
  New Window…** so the VM keeps running).

## What the result means

| `OpenGL renderer string` | Meaning |
|---|---|
| `virgl (... ANGLE ... Metal ...)` | **GPU acceleration works.** M2d done |
| `llvmpipe` | Still software. Logs will show whether UTM's virglrenderer or ANGLE failed |
| Desktop never appears | Send Logs; we fall back to the non-GL display card to finish the install |

## Next time you start this VM

Close UTM › StikDebug › Enable JIT › UTM › **legacy** › start **Debian 13**. One attach per VM start.
