#!/bin/bash
# Install launchrightsd-es as a system LaunchDaemon for DEV testing on a
# SIP-DISABLED Mac, BEFORE the Apple Endpoint Security entitlement grant.
#
#   ./scripts/install-es-dev.sh          # do NOT prefix with sudo
#
# Run this as your normal user (NOT under sudo). It builds + signs as you, then
# uses sudo only for the privileged install steps. Building under `sudo -u you`
# leaves SwiftPM with a temp/cache environment it can't open ("unable to attach
# DB"), so the build must run in your own session.
#
# Why this exists (vs the other scripts):
#   • run-es-dev.sh runs the daemon in your terminal, which lives in your GUI
#     (Aqua) session — so an elevated GUI app inherits that session by accident.
#     This script runs it under launchd in the real, SESSION-LESS system context,
#     which is what production looks like and what actually exercises the
#     audit-session-join in Launcher.spawnAsRoot.
#   • package-es.sh is the PRODUCTION path: it needs a Developer ID cert + an
#     Apple-issued ES provisioning profile. Use it once the entitlement is granted.
#
# Requirements: SIP disabled (csrutil status). The binary is ad-hoc signed WITH
# the ES entitlement embedded — mandatory even with SIP off, or es_new_client
# returns NOT_ENTITLED.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DAEMON_BIN="/usr/local/libexec/launchrightsd-es"
DAEMON_PLIST="/Library/LaunchDaemons/com.jigsaw24.launchrights.es.plist"
SUPPORT_DIR="/Library/Application Support/LaunchRights"
ALLOWLIST="$SUPPORT_DIR/allowlist.json"
ENTITLEMENTS="$REPO/Resources/launchrightsd-es.entitlements"

if [[ "$(id -u)" -eq 0 ]]; then
  echo "error: run WITHOUT sudo — it builds as you and calls sudo only for the" >&2
  echo "       privileged steps. (Building under sudo breaks SwiftPM's cache DB.)" >&2
  exit 1
fi

# Don't block, but warn loudly: without the entitlement, SIP must be off.
if csrutil status 2>/dev/null | grep -qi "enabled"; then
  echo "WARNING: SIP appears ENABLED. Without the ES entitlement the daemon will"
  echo "         fail es_new_client with NOT_ENTITLED. Disable SIP (Recovery >"
  echo "         'csrutil disable') for pre-entitlement dev testing."
fi

# Keep the build tree out of any shared folder (see run-es-dev.sh for the
# host<->VM shared-folder cache-thrash rationale).
SCRATCH="${BUILD_PATH:-$HOME/.launchrights-build}"

# A prior `sudo` build can leave root-owned files here that this (unprivileged)
# build then can't write ("attempt to write a readonly database"). Detect it and
# tell the user how to clear it, rather than emit a confusing half-build.
if [[ -d "$SCRATCH" ]] && find "$SCRATCH" ! -user "$(id -un)" -print -quit 2>/dev/null | grep -q .; then
  echo "error: $SCRATCH contains files not owned by $(id -un) (likely a prior sudo build)." >&2
  echo "       Clear it and re-run:  sudo rm -rf \"$SCRATCH\"" >&2
  exit 1
fi

echo "==> Building (release) into $SCRATCH …"
swift build -c release --package-path "$REPO" --scratch-path "$SCRATCH"
BUILD_DIR="$(swift build -c release --package-path "$REPO" --scratch-path "$SCRATCH" --show-bin-path)"

echo "==> Escalating for install (you may be prompted for your password)…"
sudo true

echo "==> Installing daemon binary -> $DAEMON_BIN"
sudo install -d -m 755 /usr/local/libexec
sudo install -m 755 "$BUILD_DIR/launchrightsd-es" "$DAEMON_BIN"

echo "==> Ad-hoc signing with the ES entitlement (required even with SIP off)…"
sudo codesign --force --sign - --options runtime --entitlements "$ENTITLEMENTS" "$DAEMON_BIN"
if sudo codesign -d --entitlements :- "$DAEMON_BIN" 2>/dev/null | grep -q "endpoint-security"; then
  echo "    entitlement embedded OK"
else
  echo "    WARNING: ES entitlement did NOT embed — es_new_client will fail" >&2
fi

echo "==> Installing allowlist…"
# An earlier stray `cp` can leave SUPPORT_DIR as a FILE instead of a directory,
# which breaks both `install -d` and the daemon's allowlist load. Clear it.
if [[ -e "$SUPPORT_DIR" && ! -d "$SUPPORT_DIR" ]]; then
  echo "    $SUPPORT_DIR is a file, not a directory — removing it"
  sudo rm -f "$SUPPORT_DIR"
fi
sudo install -d -m 755 "$SUPPORT_DIR"
if [[ ! -f "$ALLOWLIST" ]]; then
  sudo install -m 644 "$REPO/Resources/allowlist.example.json" "$ALLOWLIST"
  echo "    wrote example allowlist -> $ALLOWLIST"
else
  echo "    keeping existing $ALLOWLIST"
fi
sudo chown -R root:wheel "$SUPPORT_DIR"

echo "==> Installing + (re)loading LaunchDaemon…"
sudo install -m 644 "$REPO/Resources/com.jigsaw24.launchrights.es.plist" "$DAEMON_PLIST"
sudo chown root:wheel "$DAEMON_PLIST"
sudo launchctl bootout system "$DAEMON_PLIST" 2>/dev/null || true
sudo launchctl bootstrap system "$DAEMON_PLIST"

cat <<EOF

Loaded. Watch it come up — expect "watching AUTH_EXEC for N allowlisted app(s)":
  sudo tail -f /var/log/launchrightsd-es.log

Then, from the GUI session, trigger an elevation:
  open -a Chess           # should appear on your display, running as root

Troubleshooting (from the log line for com.apple.Chess):
  • NOT_ENTITLED  -> SIP still on, or entitlement didn't embed (re-run this script)
  • NOT_PERMITTED -> grant Full Disk Access to $DAEMON_BIN
                     (System Settings > Privacy & Security > Full Disk Access)
  • launched ... as root but NO window -> the audit-session join didn't take;
                     capture the log and we'll dig in.

Uninstall:
  sudo launchctl bootout system "$DAEMON_PLIST"
  sudo rm -f "$DAEMON_PLIST" "$DAEMON_BIN"
EOF
