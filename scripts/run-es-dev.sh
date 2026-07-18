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

echo "==> Building (release)…"
swift build -c release --package-path "$REPO"
BIN="$(swift build -c release --package-path "$REPO" --show-bin-path)/launchrightsd-es"

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
