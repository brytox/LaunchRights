#!/bin/bash
# Generate the Xcode project and build the LaunchRights host app + embedded ES system
# extension. Run after the entitlement grant, with signing identities in place.
#
# Required env:
#   DEVELOPMENT_TEAM  your Team ID (e.g. AB12CD34EF)
#   SIGN_IDENTITY     "Developer ID Application: Org (TEAMID)"  (distribution)
#                     or "Apple Development: You (…)"           (local dev)
#   HOST_PROFILE      provisioning profile (name or UUID) for com.jigsaw24.launchrights
#                     — capability: System Extension
#   EXT_PROFILE       provisioning profile for com.jigsaw24.launchrights.es
#                     — capability: Endpoint Security
#
# Local dev without notarization: enable developer mode first —
#   systemextensionsctl developer on
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
command -v xcodegen >/dev/null || { echo "install XcodeGen: brew install xcodegen" >&2; exit 1; }
: "${DEVELOPMENT_TEAM:?set DEVELOPMENT_TEAM to your Team ID}"
: "${SIGN_IDENTITY:?set SIGN_IDENTITY (see: security find-identity -v -p codesigning)}"
: "${HOST_PROFILE:?set HOST_PROFILE to the host provisioning profile}"
: "${EXT_PROFILE:?set EXT_PROFILE to the extension provisioning profile}"

cd "$DIR"
echo "==> Generating LaunchRights.xcodeproj…"
xcodegen generate

echo "==> Building (Release)…"
xcodebuild -project LaunchRights.xcodeproj -scheme LaunchRights -configuration Release \
  -derivedDataPath build build

APP="$DIR/build/Build/Products/Release/LaunchRights.app"
echo
echo "Built: $APP"
echo "Verify the embedded extension + its entitlement:"
echo "  codesign -dv --entitlements :- \"$APP/Contents/Library/SystemExtensions/com.jigsaw24.launchrights.es.systemextension\""
echo
echo "Install + activate:"
echo "  cp -R \"$APP\" /Applications/           # extensions only activate from /Applications"
echo "  open /Applications/LaunchRights.app         # menu bar ▸ Activate / Update Extension"
echo "  # then approve in System Settings ▸ Privacy & Security (or via MDM sysext policy)"
