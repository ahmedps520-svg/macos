# Every 7 days, and recovering after expiry

A free Apple ID signs apps for **7 days**. After that, sideloaded apps (UTM, StikDebug, VMLab)
**stop opening**, but **their data is still on the iPad**: VMs, pairing file, settings.

## The rule: never delete an expired app

Reinstall the **same IPA** over it with Sideloadly, using the **same Apple ID**. The app keeps
its data, including every VM inside UTM. Deleting the app deletes its data. For UTM that means
the VM disks, so the Debian install would be lost.

| App | What to do when it expires | Data kept? |
|---|---|---|
| UTM fork | Sideloadly › same `UTM-fork-….ipa` › same Apple ID | Yes, VMs kept |
| StikDebug | Sideloadly › same `StikDebug-….ipa` | Yes, pairing file kept |
| LocalDevVPN | From the App Store, never expires | — |

Optional: in Sideloadly, turn on **automatic app refreshing** so the PC re-signs the apps
over Wi-Fi before they expire, while it is on and on the same network.

## Backing up a VM

In UTM, press and hold the VM › **Share** / **Export**, and save the `.utm` file to **iCloud Drive**
or a folder that is not inside UTM. Files under *On My iPad › UTM* belong to UTM and are deleted
with it.

## If everything was deleted (2026-10-12)

Order to rebuild, using the guides already in this folder:

1. **StikDebug**: install with Sideloadly (`JIT-STIKDEBUG.md`, A2), then **iloader › Manage
   Pairing File › Place** next to StikDebug again (A3). LocalDevVPN usually survives; reinstall
   from the App Store if not.
2. **UTM fork**: newest green *Build UTM fork (iOS)* run on GitHub Actions. As of 2026-10-12 that is
   run 37058895443 (`UTM-fork-ipa-39c9361…`, includes the Logs patch and the Vulkan shm fix;
   artifact available until 2026-11-01).
3. **Debian 13 VM**: `M2-DEBIAN.md` (now with the install pitfalls), 3072 MB memory, OpenGL
   acceleration on. Then `mesa-utils`/`vulkan-tools` to re-check GPU, and continue with
   `M3-STEAM.md`.
4. VMLab is optional now. Skip it if you want to stay within the 3-app limit.

## When the build artifacts expire

GitHub keeps build downloads for 30 days. To get a fresh one: Actions › **Build UTM fork (iOS)** ›
**Run workflow** (branch `phase2-m1a-ci`). Separately, UTM's prebuilt dependency bundle that our CI
downloads expires around **2026-12-01**. After that CI builds the dependencies itself, which is slow.
That needs a plan before December.
