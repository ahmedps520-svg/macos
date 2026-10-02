# Patches on top of upstream UTM

Applied by `.github/workflows/build-utm.yml` with `git apply`, in file-name order, to the
commit pinned in `../UPSTREAM`. Keep each patch small and single-purpose; name them
`NNNN-short-description.patch`.

| Patch | Purpose |
|---|---|
| `0001-vmlab-log-screen.patch` | Captures stdout/stderr (UTM + QEMU output) from app start into memory; adds **Settings › Logs** with Copy, Export and Refresh, showing device, memory and JIT/debugger status. Touches `Platform/Main.swift` and `Platform/iOS/UTMSettingsView.swift` only, so UTM's Xcode project file is not edited. |
