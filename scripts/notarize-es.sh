#!/bin/bash
# Notarize + staple the signed LaunchRightsES.app bundle for distribution to other
# Macs (Gatekeeper). NOT needed to run on your own machine — Developer ID signing
# + the embedded profile is enough for that. Run after package-es.sh.
#
# One-time credential setup:
#   xcrun notarytool store-credentials LaunchRightsNotary \
#     --apple-id "you@org.com" --team-id "TEAMID" --password "app-specific-password"
#
# Required env:
#   NOTARY_PROFILE   the keychain profile name from store-credentials (e.g. LaunchRightsNotary)
# Optional:
#   OUT_DIR          build output dir (default: ./build)
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
: "${NOTARY_PROFILE:?set NOTARY_PROFILE (see xcrun notarytool store-credentials)}"
OUT_DIR="${OUT_DIR:-$REPO/build}"
APP="$OUT_DIR/LaunchRightsES.app"
ZIP="$OUT_DIR/LaunchRightsES.zip"

[[ -d "$APP" ]] || { echo "error: $APP not found — run ./scripts/package-es.sh first" >&2; exit 1; }

echo "==> Zipping bundle for submission…"
rm -f "$ZIP"
/usr/bin/ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Submitting to notary service (this can take a few minutes)…"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling ticket to the bundle…"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

echo "==> Gatekeeper assessment…"
spctl -a -vv --type execute "$APP" || true

echo "Done. Notarized + stapled: $APP"
