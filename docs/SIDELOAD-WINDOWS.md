# Installing a VMLab build from Windows (free Apple ID)

This is the step-by-step for milestone **M1a**: get a build made by GitHub Actions onto your
iPad Pro (M5, iPadOS 27) using only a Windows PC and a free Apple ID. JIT (StikDebug) comes
in M1b; you do not need it for this page.

Time: about 30 minutes the first time, 2 minutes afterwards.

## 0. One-time preparation on the PC

1. **Uninstall** any iTunes or iCloud you installed from the **Microsoft Store**. Tools that
   talk to the iPad need Apple's own installers.
2. Install **iTunes for Windows (64-bit) from apple.com**, not the Store:
   <https://www.apple.com/itunes/download/win64>
3. Download **Sideloadly** from <https://sideloadly.io/> and install it. Version 0.70.1 or
   newer. (Sideloadly is the simplest tool for one app. SideStore and AltStore come later,
   when you need on-device weekly refresh or JIT.)
4. Decide which Apple ID you will use. A **separate free Apple ID just for sideloading** is
   strongly recommended: in 2026 Apple has been soft-banning some free accounts that sign
   many apps, and you do not want your main account affected. The ID must have two-factor
   authentication on (Apple forces this). You do **not** need an app-specific password with a
   free ID; you sign in with the normal password and type the 2FA code.

## 1. One-time preparation on the iPad

1. Plug the iPad into the PC with a USB-C cable. Unlock it. When the iPad asks **Trust This
   Computer?**, tap **Trust** and enter your passcode. Let iTunes see the iPad once.
2. Turn on **Developer Mode**: Settings → Privacy & Security → scroll to the bottom →
   **Developer Mode** → on → the iPad restarts → after restart tap **Turn On** and enter the
   passcode. If the Developer Mode switch is missing, it appears only after step 1 (first
   pairing with a computer). Developer Mode is required to run any sideloaded app.

## 2. Download the IPA from GitHub Actions

1. Open <https://github.com/ahmedps520-svg/macos/actions> and sign in to GitHub.
2. Click the newest **Build iOS IPA** run with a green check.
3. Scroll to **Artifacts** and download **VMLab-ipa-…** (a .zip). Unzip it; inside is
   `VMLab.ipa`.
   (Artifacts can only be downloaded while signed in. They are kept for 30 days.)

## 3. Install with Sideloadly

1. Connect the iPad by USB and unlock it.
2. Open Sideloadly. The iPad should appear in the device box. If it says "no device", unplug,
   replug, and check that iTunes (from apple.com) is installed.
3. Drag `VMLab.ipa` onto the IPA box, or click the IPA icon and pick the file.
4. Enter the sideloading Apple ID in **Apple account**.
5. Leave the defaults. (Advanced options you can ignore for now.)
6. Click **Start**. Enter the Apple ID password when asked, then the 6-digit 2FA code shown on
   your Apple devices.
7. Wait for "Done." The first run can take a few minutes because Apple creates a certificate
   for your free account.

## 4. Trust the developer profile on the iPad

1. The VMLab icon is on the Home Screen but will not open yet.
2. Settings → General → **VPN & Device Management** → under *Developer App* tap your Apple
   ID → **Trust "…"** → **Trust**. On iPadOS 18 and later the button may read
   **Allow & Restart**. The iPad needs internet for this step (it checks with Apple).
3. Open **VMLab**. You should see the VMLab status screen with Build, Device and JIT
   readiness sections.

## 5. Send the result back

On the VMLab screen tap **Copy full log** and paste it into the chat, or **Export log as
file** and send the .txt. Also send one screenshot of the screen. That completes **M1a**.

Expected at this stage: *Debugger attached* ✗, *get-task-allow* ✓, *mmap(MAP_JIT) probe*
fails. That is normal before JIT is enabled in M1b.

## Every 7 days

The free certificate expires after 7 days and the app stops opening. Reinstall the same
IPA with Sideloadly (steps 3–4; the trust step is usually not needed again). Sideloadly
has an "Automatic App Refreshing" option under its settings that re-signs over Wi-Fi while
the PC is on and on the same network; you can turn it on once the basic install works.

## If something goes wrong

| Symptom | Likely cause | Fix |
|---|---|---|
| Sideloadly says "no device" | Microsoft Store iTunes, or missing driver | Uninstall Store iTunes, install from apple.com, reboot PC |
| "Please enter your app-specific password" | Only for paid IDs | Use the normal password; make sure 2FA is on |
| Error about "10 App IDs" | Free-ID limit: 10 new app IDs per 7 days | Wait, or reuse the same bundle ID (Sideloadly does this by default) |
| Error about "3 apps" | Free-ID limit: 3 sideloaded apps installed at once | Delete another sideloaded app first |
| "provisioning profile is banned" (0xe8008024) | Apple soft-banned that free account | Use a different (new) free Apple ID |
| App icon greyed out or "Unable to Verify App" | Profile not trusted, or no internet | Step 4; connect to Wi-Fi |
| App opens and closes immediately | Developer Mode off, or certificate expired | Step 1.2, or reinstall |
| Install succeeds but app crashes on launch | A real bug in our build | Reinstall once; if it repeats, tell me the exact iPadOS version and the steps |

If the app crashes before the log screen appears, the crash log helps: Settings → Privacy &
Security → Analytics & Improvements → Analytics Data → look for a file starting with
`VMLab-` → share it.
