# M2d — GPU acceleration test (OpenGL through virgl → ANGLE → Metal)

Goal: prove that 3D graphics drawn inside the Linux VM are rendered by your iPad's GPU, not
emulated in software. We use the Alpine VM from M1c, switch its display card to the
GPU-accelerated one, install Mesa's virtual GPU driver, and run `kmscube`, a tiny program that
draws a spinning cube and prints which renderer it used. No desktop needed yet.

The path being tested:

```
kmscube (in Linux) → Mesa "virgl" driver → virtio-gpu device → QEMU virglrenderer
  → ANGLE (OpenGL ES on top of Metal) → Metal → iPad GPU → UTM's window
```

About 20 minutes. Needs Wi-Fi (the VM downloads ~60 MB of packages).

## 1. Switch the VM to the GPU-accelerated display card

1. In UTM, make sure the Alpine VM is **stopped** (power button in the VM toolbar, or it's not
   running).
2. On the VM list, press and hold **Alpine** › **Edit** (or select it and tap the settings icon).
3. Open **Display**.
4. **Emulated Display Card**: choose **virtio-gpu-gl-pci (GPU Supported)**.
5. Save.

Leave UTM's own app setting **Renderer Backend** at its default (ANGLE Metal).

## 2. Start UTM through StikDebug and boot

Same as before, because one StikDebug attach covers one VM start:

1. Close UTM completely (swipe it away).
2. LocalDevVPN on, Wi-Fi on.
3. StikDebug › **Enable JIT** › **UTM** › **legacy** script.
4. In UTM tap **Alpine** › **▶**. Wait for `login:` (1–2 minutes).
5. Press **Alt+F2**, log in as `root`, press Return at `Password:`.

If the screen stays black for more than 3 minutes **with the new card**, that itself is a result:
stop the VM, send me **Settings › Logs › Copy**, and switch the card back to `virtio-gpu-pci`.

## 3. Give the VM internet

Type these one line at a time (Return after each):

```
ip link set eth0 up
udhcpc -i eth0
```

You should see a line like `lease of 10.0.2.15 obtained`. Then point Alpine at its online
package repositories:

```
echo https://dl-cdn.alpinelinux.org/alpine/v3.24/main > /etc/apk/repositories
echo https://dl-cdn.alpinelinux.org/alpine/v3.24/community >> /etc/apk/repositories
apk update
```

`apk update` should end with `OK: ... distinct packages available`.

## 4. Install the GPU driver and test programs

```
apk add mesa-dri-gallium mesa-utils kmscube
```

Wait until it finishes (emulation makes installs slow; a few minutes is normal).

## 5. Check that the virtual GPU has 3D

```
dmesg | grep -i -E "virgl|virtio_gpu|drm"
ls /dev/dri
```

What to look for:
- `dmesg` shows a line containing **`+virgl`** (for example `[drm] features: +virgl ...`).
  `-virgl` means the GPU card is there but 3D is off.
- `ls /dev/dri` shows `card0` and `renderD128`.

Take a **screenshot** here.

## 6. Run the cube

```
kmscube
```

- It first prints a few lines including **`GL_RENDERER:`**. Then the screen switches to a
  spinning cube.
- Let it spin for about 10 seconds, then stop it with **Ctrl+C** (UTM's key row has Ctrl, or use
  a hardware keyboard).
- Back at the prompt, scroll position may have moved. Take a **screenshot** that shows the
  `GL_RENDERER` line. If it scrolled away, run `kmscube 2>&1 | head -n 20` and immediately press
  Ctrl+C after the cube appears.

## 7. Send the results

1. Screenshot from step 5 and the screenshot showing `GL_RENDERER`.
2. Optional: a short screen recording of the spinning cube (Control Center › Screen Recording).
3. UTM **Settings › Logs › Copy**, pasted into the chat.

## What the result means

| What you see | Meaning |
|---|---|
| `GL_RENDERER: virgl (...)` and a smoothly spinning cube | **GPU acceleration works.** Linux's OpenGL is drawn by the iPad GPU through ANGLE/Metal. M2d done |
| `GL_RENDERER: llvmpipe` | 3D is rendered in software on the emulated CPU. The virgl path is not active; the logs and `dmesg` tell us which layer |
| `dmesg` shows `-virgl` | The display card is not the GL one, or UTM's renderer failed to start; check step 1, send logs |
| `kmscube` says "failed to ..." / no `/dev/dri` | The guest driver didn't load; send `dmesg` screenshot |
| UTM closes when the VM starts or when kmscube starts | Crash in the host graphics stack; send Logs immediately after reopening UTM |
| Black screen > 3 min after switching the card | UTM's GL device didn't come up on iOS; send Logs, switch the card back |

## Notes

- Everything installed in step 4 lives in RAM on this live ISO and disappears when the VM stops.
  Making it permanent is the "persistence" milestone.
- This is OpenGL only. Vulkan (needed by most modern games) is a separate milestone.
