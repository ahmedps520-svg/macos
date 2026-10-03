# M2e — Vulkan in the Debian 13 VM (Venus → MoltenVK/KosmicKrisp → Metal)

Most modern games and translation layers (DXVK, VKD3D, Proton) need **Vulkan**. UTM passes
Vulkan from the VM to the iPad with **Venus** (Mesa's virtio Vulkan driver in the guest,
virglrenderer's Venus on the host) and then **MoltenVK** (default) or **KosmicKrisp** translates
Vulkan to Metal. The guest kernel already advertised the Venus capability (cap set id 4) on Alpine.
On Alpine, Venus failed at `vkCreateInstance` with `ERROR_OUT_OF_HOST_MEMORY`; this test repeats
it on Debian with a mainstream Mesa.

## First result (2026-10-02, build f6ece4a) and fix

On device, `vulkaninfo` failed with `ERROR_OUT_OF_HOST_MEMORY`. With `VN_DEBUG=init,result` the
guest showed `connected to renderer` ... `failed to allocate/map ring shmem`. Software Vulkan
(lavapipe) works when selected alone, so only Venus fails. Cause (from UTM's virglrenderer
source): the shared ring buffer is created with `shm_open`, which iOS only allows under the app's
App Group prefix, and our sideloaded IPA has no App Group entitlement. Fix: virglrenderer patch
`utm/virglrenderer-patches/0001-ios-anon-file-fallback.patch` falls back to an unlinked file in
UTM's temp directory; CI rebuilds only virglrenderer (build **39c9361** and later). **Confirmed on
device 2026-10-03:** `vulkaninfo` lists `Virtio-GPU Venus (Apple M5 GPU)`, Vulkan 1.3.269.

**Install the UTM fork build 39c9361 or newer before repeating the steps below.**

## Steps (inside Debian 13, Terminal Emulator)

Start the VM as usual (StikDebug › Enable JIT › UTM › **legacy**, then ▶), log in, open Terminal.

1. Install the Vulkan drivers and tools:
   ```
   sudo apt install -y mesa-vulkan-drivers vulkan-tools
   ```
2. List the Vulkan devices:
   ```
   vulkaninfo --summary
   ```
   Screenshot the **Devices** section at the end. Look at each `deviceName`.
3. If a Venus device is listed, run the Vulkan cube (it opens a window; close it after ~10 s):
   ```
   vkcube
   ```
4. Bonus, OpenGL on top of Vulkan (zink):
   ```
   MESA_LOADER_DRIVER_OVERRIDE=zink glxinfo -B | grep -i "renderer string"
   ```

## Reading the result

| What you see | Meaning |
|---|---|
| A device named **`Virtio-GPU Venus (...)`** (often with "Apple" in the name) | **Vulkan reaches the iPad GPU.** M2e done |
| Only **`llvmpipe`** (lavapipe, software) | Venus did not initialise; send UTM Logs |
| `vkCreateInstance failed with ERROR_OUT_OF_HOST_MEMORY` (same as Alpine) | Host-side Venus problem; next try UTM Settings › **Vulkan Driver › KosmicKrisp** |
| UTM freezes or closes | Report it with Logs after reopening UTM |

## If it fails: try KosmicKrisp

1. Power off the VM. In UTM's **Settings** (gear), set **Vulkan Driver** to **KosmicKrisp**.
2. Close UTM, re-attach with StikDebug (legacy), start Debian, repeat step 2.
3. Also send UTM **Settings › Logs › Copy** (open it with the VM toolbar's Display › New Window…).
