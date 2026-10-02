# Enabling JIT for VMLab with StikDebug (milestone M1b)

JIT (letting the app generate machine code at runtime) is what makes QEMU usable. On your
iPad (M5, iPadOS 27) Apple's Trusted Execution Monitor blocks it unless a debugger prepares the
memory. **StikDebug** is a sideloaded app that acts as that debugger, on the iPad itself,
with no PC needed after a one-time pairing. VMLab implements the matching handshake
(the "universal" script protocol).

You need three things installed on the iPad once, then one tap per launch.

Time: about 20 minutes the first time.

## Part A — one-time setup

### A1. Install LocalDevVPN (App Store)
On the iPad, open the App Store and install **LocalDevVPN** (free). It is a loopback VPN
that lets StikDebug talk to the iPad's own debug service. StikDebug does not work without it.
Open it once and allow it to add a VPN configuration.

### A2. Install StikDebug with Sideloadly
1. On the PC download the IPA:
   <https://github.com/StikDebug/StikDebug/releases/download/3.1.13/StikDebug-3.1.13.ipa>
   (or the newest from <https://github.com/StikDebug/StikDebug/releases>).
2. Plug in the iPad, open Sideloadly, drag `StikDebug-3.1.13.ipa` in, same Apple ID as before,
   **Start**, password, 2FA code.
3. The profile is already trusted from VMLab, so StikDebug should open directly.
   You now use 2 of your 3 free-ID app slots (VMLab, StikDebug).

### A3. Create the pairing file with iloader (Windows)
StikDebug needs a "pairing file" that proves the iPad trusts your PC. It is made once.
1. Download and run the iloader installer for Windows:
   <https://github.com/nab138/iloader/releases/latest/download/iloader-windows-x64.exe>
   (iTunes from apple.com must be installed; it already is.)
2. Keep the iPad connected by USB and unlocked. Open **iloader**.
3. Click **Manage Pairing File**.
4. In the list, find **StikDebug** and click **Place** next to it. You should see
   "Pairing file placed successfully!" in green.
   If VMLab or other apps are listed you can ignore them.

Note: the pairing file expires if you update or reset the iPad. Repeat A3 then.

### A4. First launch of StikDebug
1. On the iPad, open **LocalDevVPN** and turn the VPN **on** (the VPN icon appears in the status bar).
2. Open **StikDebug**. If it asks for a pairing file, it should find the one iloader placed.
   If it asks you to import one, tell me.
3. The first time, StikDebug downloads and mounts the "Developer Disk Image". Wait for it to
   finish (needs internet). This repeats after iPadOS updates.
4. Stay on Wi-Fi. Since iPadOS 26.4 this does not work offline.

## Part B — every time you want JIT in VMLab

1. Make sure the LocalDevVPN VPN is on.
2. Open **VMLab**.
3. In the **JIT (M1b)** section tap **Enable JIT with StikDebug**.
   - iPadOS switches to StikDebug. StikDebug should show it is attaching to VMLab with the
     *universal* script.
   - Switch back to VMLab (swipe up, pick VMLab). Within a few seconds the State line should
     say **JIT ready (test returned 42)**.
4. Tap **Copy full log** and paste it here. That confirms M1b.

### If "Enable JIT with StikDebug" does nothing
Use the manual path:
1. In VMLab tap **Wait for debugger (manual attach)**. It counts down.
2. Switch to StikDebug → **Enable JIT** → choose **VMLab** from the list.
3. If StikDebug asks which script to use, choose **universal** (not legacy, not none).
4. Switch back to VMLab and read the State line.

**Important:** if a debugger attaches to VMLab *without* the universal script, VMLab will
crash when it tries the handshake. That is expected behaviour of Apple's protection, not a
bug to fix on the iPad. Just pick the universal script next time.

## What the result means

| State line | Meaning |
|---|---|
| waiting for debugger (Ns) | VMLab is polling for the CS_DEBUGGED flag |
| debugger attached | StikDebug attached; the handshake starts in half a second |
| JIT ready (test returned 42) | VMLab wrote machine code into memory and executed it. **M1b done.** |
| region setup failed at … | Tells me which step failed (mmap, vm_remap, mprotect, brk). Paste the log |
| failed: no debugger attached within … | StikDebug never attached: VPN off? pairing file? Wi-Fi? |

## Troubleshooting

| Symptom | Fix |
|---|---|
| StikDebug: "heartbeat" or "connection dropped" | VPN off, or not on Wi-Fi. Turn LocalDevVPN on, reconnect Wi-Fi, reopen StikDebug |
| StikDebug: pairing file invalid | Redo A3 with the iPad unlocked and trusted |
| StikDebug: DDI mount fails | Needs internet; retry; after an iPadOS update it must re-download |
| VMLab not in StikDebug's list | VMLab must be signed with get-task-allow (it is, per your M1a log); reinstall VMLab |
| VMLab crashes on "Enable JIT" | A debugger attached without the universal script, or the handshake itself crashed. Send the crash log: Settings › Privacy & Security › Analytics & Improvements › Analytics Data › `VMLab-…` |
