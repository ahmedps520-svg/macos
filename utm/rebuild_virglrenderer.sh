#!/usr/bin/env bash
# Rebuild only virglrenderer (with utm/virglrenderer-patches/*.patch) on top of an existing
# UTM sysroot, instead of rebuilding every dependency (hours).
#
# Reuses UTM's own scripts/build_dependencies.sh for the toolchain/meson setup: we take the
# script up to (not including) its main build sequence, then run just the virglrenderer step.
#
# usage (from the upstream UTM checkout): rebuild_virglrenderer.sh <patch-dir> [platform] [arch]
set -euo pipefail

PATCH_DIR="$(cd "${1:?patch dir required}" && pwd)"
PLATFORM="${2:-ios}"
ARCH="${3:-arm64}"

[ -f scripts/build_dependencies.sh ] || { echo "run from the upstream UTM checkout" >&2; exit 1; }

# 1. Everything before the main sequence (it starts at the bare `check_env` call).
MAIN_LINE=$(grep -n '^check_env$' scripts/build_dependencies.sh | tail -n1 | cut -d: -f1)
[ -n "$MAIN_LINE" ] || { echo "could not find main section in build_dependencies.sh" >&2; exit 1; }
HELPER=scripts/build_virgl_only.sh
head -n $((MAIN_LINE - 1)) scripts/build_dependencies.sh > "$HELPER"

# 2. Our main sequence.
cat >> "$HELPER" <<'MAIN'

echo "${GREEN}Rebuilding virglrenderer only, PREFIX=$PREFIX${NC}"
[ -d "$PREFIX/lib/pkgconfig" ] || { echo "${RED}no sysroot at $PREFIX${NC}"; exit 1; }

# The prebuilt sysroot was made on another machine: point its pkg-config files and the bundled
# host pkg-config at this location.
OLD_PREFIX=$(sed -n 's/^prefix=//p' "$PREFIX/lib/pkgconfig/epoxy.pc" | head -n1)
if [ -n "$OLD_PREFIX" ] && [ "$OLD_PREFIX" != "$PREFIX" ]; then
    echo "${GREEN}Relocating .pc files: $OLD_PREFIX -> $PREFIX${NC}"
    grep -rl "$OLD_PREFIX" "$PREFIX/lib/pkgconfig" "$PREFIX/share/pkgconfig" 2>/dev/null \
        | while read -r pc; do sed -i '' "s#$OLD_PREFIX#$PREFIX#g" "$pc"; done
fi
export PATH="$PREFIX/host/bin:$PATH"
export PKG_CONFIG="$PREFIX/host/bin/pkg-config"
export PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig"
"$PKG_CONFIG" --modversion epoxy vulkan

mkdir -p "$BUILD_DIR"
clone $VIRGLRENDERER_REPO $VIRGLRENDERER_COMMIT
VIRGL_SRC="$BUILD_DIR/$(basename $VIRGLRENDERER_REPO)"
for p in "$VIRGL_PATCH_DIR"/*.patch; do
    [ -f "$p" ] || continue
    echo "${GREEN}Applying $(basename "$p")${NC}"
    git -C "$VIRGL_SRC" apply --whitespace=nowarn "$p"
done

if [ "$PLATFORM" == "macos" ]; then
    VIRGL_RENDER_SERVER_MODE="process"
else
    VIRGL_RENDER_SERVER_MODE="thread"
fi
meson_darwin_build $VIRGLRENDERER_REPO -Dtests=false -Dcheck-gl-errors=false -Dvenus=true -Dneptune=true -Dvulkan-dload=false -Drender-server-mode="$VIRGL_RENDER_SERVER_MODE"

# Turn the freshly installed dylib into the framework the Xcode project embeds, with imports
# rewritten to @rpath frameworks (also for libraries whose ids still name the old prefix).
LIB="$PREFIX/lib/libvirglrenderer.1.dylib"
[ -f "$LIB" ] || LIB="$(readlink -f "$PREFIX/lib/libvirglrenderer.dylib")"
FW_DIR="$PREFIX/Frameworks/virglrenderer.1.framework"
[ -d "$FW_DIR" ] || { echo "${RED}missing $FW_DIR in sysroot${NC}"; exit 1; }
cp -f "$LIB" "$FW_DIR/virglrenderer.1"
install_name_tool -id "@rpath/virglrenderer.1.framework/virglrenderer.1" "$FW_DIR/virglrenderer.1"
for dep in $(otool -L "$FW_DIR/virglrenderer.1" | tail -n +2 | awk '{print $1}'); do
    case "$dep" in
    */sysroot-*/lib/*.dylib | @rpath/lib*.dylib )
        base=$(basename "$dep"); name=${base%.*}; name=${name#lib}
        install_name_tool -change "$dep" "@rpath/$name.framework/$name" "$FW_DIR/virglrenderer.1"
        ;;
    esac
done
echo "${GREEN}virglrenderer framework now links:${NC}"
otool -L "$FW_DIR/virglrenderer.1"
strings "$FW_DIR/virglrenderer.1" | grep -q "file-backed fallback" && echo "${GREEN}patch present in binary${NC}"
MAIN

chmod +x "$HELPER"
VIRGL_PATCH_DIR="$PATCH_DIR" NCPU="${NCPU:-0}" "$HELPER" -p "$PLATFORM" -a "$ARCH"
