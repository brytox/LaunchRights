#!/bin/bash
# Wrap launchrightsd-es in a signed .app bundle so it can carry the Endpoint Security
# provisioning profile. A naked CLI tool CANNOT use the ES entitlement on a
# SIP-enabled Mac — the entitlement must be whitelisted by an embedded profile,
# and only a bundle can hold one. Run this once Apple grants the entitlement.
#
# Prereqs (after the grant):
#   1. Portal: create App ID "com.jigsaw24.launchrights.es" with the Endpoint Security
#      capability enabled (match Resources/LaunchRightsES-Info.plist CFBundleIdentifier).
#   2. Portal: create a *Developer ID* provisioning profile for that App ID and
#      download the .provisionprofile.
#
# Required env:
#   DEV_ID_APP         "Developer ID Application: Your Org (TEAMID)"
#   PROVISION_PROFILE  path to the downloaded .provisionprofile
# Optional:
#   OUT_DIR            build output dir (default: ./build)
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
: "${DEV_ID_APP:?set DEV_ID_APP to your 'Developer ID Application: …' identity (see: security find-identity -v -p codesigning)}"
: "${PROVISION_PROFILE:?set PROVISION_PROFILE to your Developer ID .provisionprofile}"
[[ -f "$PROVISION_PROFILE" ]] || { echo "error: no file at PROVISION_PROFILE=$PROVISION_PROFILE" >&2; exit 1; }

OUT_DIR="${OUT_DIR:-$REPO/build}"
APP="$OUT_DIR/LaunchRightsES.app"
ENTITLEMENTS="$REPO/Resources/launchrightsd-es.entitlements"

echo "==> Building release…"
swift build -c release --package-path "$REPO"
BIN="$(swift build -c release --package-path "$REPO" --show-bin-path)"

echo "==> Assembling bundle: $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN/launchrightsd-es"                    "$APP/Contents/MacOS/launchrightsd-es"
cp "$REPO/Resources/LaunchRightsES-Info.plist" "$APP/Contents/Info.plist"
cp "$PROVISION_PROFILE"                    "$APP/Contents/embedded.provisionprofile"

echo "==> Signing bundle (Developer ID + hardened runtime + ES entitlement)…"
codesign --force --sign "$DEV_ID_APP" --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" "$APP"

echo "==> Verifying signature…"
codesign --verify --strict --verbose=2 "$APP"
echo "--- embedded entitlements ---"
codesign -d --entitlements :- "$APP" 2>/dev/null || true
echo "--- provisioning profile present ---"
[[ -f "$APP/Contents/embedded.provisionprofile" ]] && echo "yes" || echo "MISSING"

cat <<EOF

Bundle ready: $APP

Install + run (no SIP-off needed once the entitlement + profile are real):
  sudo mkdir -p "/Library/Application Support/LaunchRights"
  sudo cp -R "$APP" "/Library/Application Support/LaunchRights/LaunchRightsES.app"
  sudo cp "$REPO/Resources/com.jigsaw24.launchrights.es-signed.plist" \\
          /Library/LaunchDaemons/com.jigsaw24.launchrights.es.plist
  sudo chown -R root:wheel "/Library/Application Support/LaunchRights/LaunchRightsES.app" \\
          /Library/LaunchDaemons/com.jigsaw24.launchrights.es.plist
  sudo launchctl bootstrap system /Library/LaunchDaemons/com.jigsaw24.launchrights.es.plist
  sudo tail -f /var/log/launchrightsd-es.log

For distribution to OTHER Macs, notarize next:  ./scripts/notarize-es.sh
EOF
