#!/bin/bash
# Dev loop for the Endpoint Security daemon. Runs it in the foreground as root so
# you can watch decisions live. No launchd needed for testing.
#
#   ./scripts/run-es-dev.sh
#
# Optional: point at a local allowlist without installing to /Library:
#   LAUNCHRIGHTS_ALLOWLIST=./my-allowlist.json ./scripts/run-es-dev.sh
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"

# Keep the build tree OUT of the shared folder. When this repo is a host->VM
# shared folder, the default .build/ is shared between host and VM, which see
# the repo at different absolute paths (/Users/bob vs /Volumes/bob). The Swift
# ModuleCache bakes in that absolute path, so a build from one side invalidates
# the other and you get "missing required module 'SwiftShims'". A VM-local
# scratch dir avoids the collision entirely (and is much faster than shared I/O).
# Override with BUILD_PATH=... to place it elsewhere.
SCRATCH="${BUILD_PATH:-$HOME/.launchrights-build}"
BUILD=(swift build -c release --package-path "$REPO" --scratch-path "$SCRATCH")

echo "==> Building (release) into $SCRATCH …"
if ! "${BUILD[@]}"; then
  echo "==> Build failed; clearing scratch dir and retrying once…"
  rm -rf "$SCRATCH"
  "${BUILD[@]}"
fi
BIN="$("${BUILD[@]}" --show-bin-path)/launchrightsd-es"

# Endpoint Security requires the entitlement to be present in the code signature.
# With SIP disabled it need NOT be Apple-provisioned, so an ad-hoc signature (-s -)
# that embeds the entitlement is enough for dev testing. Override the identity to
# your Developer ID with CODESIGN_IDENTITY=... once the entitlement is granted.
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
ENTITLEMENTS="$REPO/Resources/launchrightsd-es.entitlements"
echo "==> Signing binary (identity: $CODESIGN_IDENTITY)…"
codesign --force --sign "$CODESIGN_IDENTITY" \
  --entitlements "$ENTITLEMENTS" \
  --options runtime \
  "$BIN"

ALLOWLIST="${LAUNCHRIGHTS_ALLOWLIST:-/Library/Application Support/LaunchRights/allowlist.json}"
if [[ ! -f "$ALLOWLIST" ]]; then
  echo "note: no allowlist found at: $ALLOWLIST"
  echo "      copy Resources/allowlist.example.json there, or set LAUNCHRIGHTS_ALLOWLIST."
fi

cat <<'EOF'
--------------------------------------------------------------------
 Endpoint Security needs ONE of:
   • the ES entitlement on a Developer ID-signed binary (production), or
   • SIP disabled (dev boxes only):   csrutil status   to check.
 If es_new_client reports NOT_PERMITTED, grant Full Disk Access to
 your terminal under System Settings > Privacy & Security.
 Edit the allowlist live, then:  sudo killall -HUP launchrightsd-es
--------------------------------------------------------------------
EOF

echo "==> Running launchrightsd-es as root (Ctrl-C to stop)…"
exec sudo LAUNCHRIGHTS_ALLOWLIST="$ALLOWLIST" "$BIN"
