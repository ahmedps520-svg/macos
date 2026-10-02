#!/usr/bin/env bash
# Turn an unsigned .xcarchive into a fake-signed .ipa that AltStore/Sideloadly/SideStore
# can re-sign. Mirrors UTM's scripts/package.sh "ipa" mode in miniature.
#
# usage: scripts/package_ipa.sh <path/to/App.xcarchive> <output.ipa>
set -euo pipefail

ARCHIVE="${1:?archive path required}"
OUTPUT="${2:?output ipa path required}"
case "$OUTPUT" in /*) ;; *) OUTPUT="$PWD/$OUTPUT" ;; esac
HERE="$(cd "$(dirname "$0")" && pwd)"
ENTITLEMENTS="$HERE/entitlements.plist"

APP_DIR="$(find "$ARCHIVE/Products/Applications" -maxdepth 1 -name '*.app' | head -n1)"
[ -n "$APP_DIR" ] || { echo "no .app found in $ARCHIVE" >&2; exit 1; }
APP_NAME="$(basename "$APP_DIR" .app)"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/Payload"
cp -R "$APP_DIR" "$WORK/Payload/"

PAYLOAD_APP="$WORK/Payload/$APP_NAME.app"
rm -rf "$PAYLOAD_APP/_CodeSignature"

# Fake-sign embedded frameworks (none yet) and the main binary with our entitlements.
find "$PAYLOAD_APP" -type d -path '*/Frameworks/*.framework' -exec ldid -S {} \;
ldid -S"$ENTITLEMENTS" "$PAYLOAD_APP/$APP_NAME"

mkdir -p "$(dirname "$OUTPUT")"
rm -f "$OUTPUT"
( cd "$WORK" && zip -qry "$OUTPUT" Payload )
echo "wrote $OUTPUT ($(du -h "$OUTPUT" | cut -f1))"
ldid -e "$PAYLOAD_APP/$APP_NAME" | sed 's/^/  entitlement: /' || true
