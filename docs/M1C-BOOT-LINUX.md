# M1c — boot Alpine Linux (ARM64) in our UTM build

Goal: our own UTM build (from this repo's CI) boots a legitimate ARM64 Linux image on your
iPad and you see its screen. About 30 minutes.

## What you need

- StikDebug, LocalDevVPN and the pairing file from M1b (already working).
- The UTM fork IPA from GitHub Actions.
- The Alpine Linux "virt" ISO for ARM64 (89 MB, official, free).

**3-app limit:** a free Apple ID allows 3 sideloaded apps at once. VMLab + StikDebug + UTM =
3, so it fits exactly. If Sideloadly says the device reached the maximum, delete VMLab from the
iPad (press and hold the icon › Remove App › Delete App) and try again. VMLab can be reinstalled
later.

## 1. Install the UTM fork (PC)

1. Open <https://github.com/ahmedps520-svg/macos/actions> and click the newest green run named
   **Build UTM fork (iOS)**.
2. Under **Artifacts**, download **UTM-fork-ipa-…** (about 145 MB zipped) and extract it.
   Inside is `UTM-fork-xxxxxxx.ipa`.
3. Install it with Sideloadly exactly like VMLab (same Apple ID, Start, password, 6-digit code).
   The first install of a large app takes a few minutes.

## 2. Download Alpine Linux (iPad)

1. On the iPad, open Safari and go to:
   <https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/aarch64/alpine-virt-3.24.2-aarch64.iso>
2. Tap **Download**. It goes to Files › Downloads. (Size about 89 MB.)

This is the official Alpine image for ARM64 virtual machines, a small text-mode Linux.

## 3. Start UTM through StikDebug (important order)

UTM must have the debugger attached **when it starts**, and it needs the **legacy** script,
not universal. (VMLab used universal. UTM uses an older breakpoint that only the legacy script
understands. With universal, the VM fails to start.)

1. If UTM is open, close it: swipe up from the bottom, hold, swipe UTM away.
2. Turn on the **LocalDevVPN** VPN. Be on Wi-Fi.
3. Open **StikDebug** › **Enable JIT** › choose **UTM** from the list (it may show a longer name
   ending in something like `.7N75CWF776`).
4. When asked for a script, choose **legacy** (`legacy.js`).
5. StikDebug opens UTM. Leave StikDebug running in the background.

If UTM shows a message saying *"Your version of iOS does not support running VMs while
unmodified…"*, the debugger was not attached at launch. Close UTM and repeat step 3.

**One attach covers one VM start.** After a VM has started, the legacy script detaches. To
start a VM again later, close UTM and repeat this whole step 3.

## 4. Create the VM (in UTM)

1. Tap **+** (Create a New Virtual Machine).
2. Tap **Emulate**. ("Virtualize" is greyed out on iPad; that is expected.)
3. Tap **Linux**.
4. Leave **Boot from ISO image** selected. Under **Boot ISO Image** tap **Browse** and pick
   `alpine-virt-3.24.2-aarch64.iso` from Downloads. Tap **Next**.
5. Hardware:
   - **Architecture**: ARM64 (aarch64).
   - **System**: leave the default.
   - **Memory**: 1024 MB.
   - **CPU Cores**: leave the default.
   - **Enable display output**: on.
   - **Enable hardware OpenGL acceleration**: **off** for this first test.
   Tap **Next**.
6. Storage: **4** GiB. Tap **Next**.
7. Shared Directory: skip. Tap **Next**.
8. Summary: name it **Alpine**. Tap **Save**.

## 5. Boot it

1. Tap the **Alpine** VM, then the big **▶ play** button.
2. You should see Linux boot messages scroll by, then a line ending in **`login:`**.
   It can take a minute or two; emulation is slow.
3. Type `root` and press Return (there is no password). You should get a `#` prompt.
   (Tap the screen to bring up the keyboard if it doesn't appear.)

## 6. Send the result

1. Take a screenshot of the VM screen (Top button + volume up).
2. Close the VM window, open UTM **Settings** (gear icon) › **Logs** (top right) › **Copy**,
   and paste here. Send the screenshot too.

M1c is done when the screenshot shows the Alpine login or `#` prompt and the log is from the
UTM fork build.

## If something goes wrong

| What you see | What it means / what to do |
|---|---|
| "Your version of iOS does not support running VMs while unmodified…" | UTM started without the debugger. Close UTM, start it from StikDebug (step 3) |
| **Emulate** greyed out | Same cause as above |
| VM window black, nothing happens for > 3 minutes | Send me the Logs (Settings › Logs › Copy) |
| UTM crashes when pressing play | Probably the universal script was chosen. Repeat step 3 with **legacy**. Then send Logs |
| Sideloadly: maximum number of apps | Delete VMLab from the iPad, retry |
| The ISO isn't listed in Browse | In Files, make sure the download finished (89 MB) and is in Downloads |
