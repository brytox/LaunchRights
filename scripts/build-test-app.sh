#!/bin/bash
# Build IDProbe.app — a headless test app for proving `runAs` privilege drops.
# When launched, it appends the identity it runs under (euid, user, groups,
# HOME) to /tmp/launchrights-idprobe.log and exits. No GUI, so it survives being
# run as a non-root user (unlike a real GUI app, which exits with no WindowServer).
#
#   ./scripts/build-test-app.sh          # run as your normal user (no sudo)
#
# Then follow the printed steps to allowlist it with "runAs":"_launchrights".
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE_ID="com.jigsaw24.launchrights.idprobe"
OUT_DIR="${OUT_DIR:-$REPO/build}"
APP="$OUT_DIR/IDProbe.app"
SCRATCH="${BUILD_PATH:-$HOME/.launchrights-build}"

if [[ "$(id -u)" -eq 0 ]]; then
  echo "error: run WITHOUT sudo (building under sudo breaks SwiftPM's cache DB)." >&2
  exit 1
fi

echo "==> Building idprobe (release) into $SCRATCH …"
swift build -c release --package-path "$REPO" --scratch-path "$SCRATCH" --product idprobe
BIN="$(swift build -c release --package-path "$REPO" --scratch-path "$SCRATCH" --show-bin-path)/idprobe"

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/idprobe"
cp "$REPO/Resources/IDProbe-Info.plist" "$APP/Contents/Info.plist"

echo "==> Ad-hoc signing the bundle (identifier = $BUNDLE_ID)…"
codesign --force --sign - --identifier "$BUNDLE_ID" "$APP"
echo "    designated requirement:"
codesign -d -r- "$APP" 2>&1 | sed 's/^/      /'

cat <<EOF

Built: $APP

1) Make the service account (once):
     sudo ./scripts/create-service-account.sh

2) Add this entry to /Library/Application Support/LaunchRights/allowlist.json
   (inside "apps"), then reload:  sudo killall -HUP launchrightsd-es
     {
       "bundleIdentifier": "$BUNDLE_ID",
       "requirement": "identifier \\"$BUNDLE_ID\\"",
       "displayName": "ID Probe (runAs test)",
       "runAs": "_launchrights"
     }

3) Trigger it and read the result:
     open "$APP"
     cat /tmp/launchrights-idprobe.log

   Expect a line with euid=<service-account-uid>(_launchrights) and admin=YES.
   Change "runAs" to "root" (or remove it) + reload to see euid=0(root) instead.
EOF
