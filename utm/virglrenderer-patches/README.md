# Patches on top of UTM's virglrenderer

Applied by `utm/rebuild_virglrenderer.sh` (called from `.github/workflows/build-utm.yml`) to the
virglrenderer commit pinned in upstream UTM's `patches/sources` (`VIRGLRENDERER_COMMIT`), after
which only virglrenderer is rebuilt into the prebuilt sysroot.

| Patch | Purpose |
|---|---|
| `0001-ios-anon-file-fallback.patch` | When `shm_open` is refused (sideloaded iOS apps without the app-group entitlement), create the shared buffer as an unlinked file in `XDG_RUNTIME_DIR`/`TMPDIR` instead. Fixes Venus (Vulkan) failing in the guest with "failed to allocate/map ring shmem" → `VK_ERROR_OUT_OF_HOST_MEMORY`. Logs `virgl: shm_open failed (...)` to stderr. |
