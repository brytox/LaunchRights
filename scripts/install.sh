#!/bin/bash
# Prototype installer for LaunchRights. Requires sudo (installs a root LaunchDaemon).
#
#   sudo ./scripts/install.sh
#
# This does a manual install (copy binaries + plists, set ownership, bootstrap
# launchd). Production would ship the daemon via SMAppService/MDM instead — see
# README "Path to production".
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DAEMON_BIN="/usr/local/libexec/launchrightsd"
AGENT_BIN="/usr/local/bin/launchrights-agent"
MENU_BIN="/usr/local/bin/launchrights-menu"
DAEMON_PLIST="/Library/LaunchDaemons/com.jigsaw24.launchrights.helper.plist"
AGENT_PLIST="/Library/LaunchAgents/com.jigsaw24.launchrights.agent.plist"
MENU_PLIST="/Library/LaunchAgents/com.jigsaw24.launchrights.menu.plist"
SUPPORT_DIR="/Library/Application Support/LaunchRights"
ALLOWLIST="$SUPPORT_DIR/allowlist.json"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "error: run with sudo" >&2
  exit 1
fi

# The GUI user (for bootstrapping the LaunchAgent into their session).
CONSOLE_USER="$(stat -f%Su /dev/console)"
CONSOLE_UID="$(id -u "$CONSOLE_USER")"

echo "==> Building (release)…"
sudo -u "$CONSOLE_USER" swift build -c release --package-path "$REPO"
BUILD_DIR="$(sudo -u "$CONSOLE_USER" swift build -c release --package-path "$REPO" --show-bin-path)"

echo "==> Installing binaries…"
install -d -m 755 /usr/local/libexec /usr/local/bin
install -m 755 "$BUILD_DIR/launchrightsd" "$DAEMON_BIN"
install -m 755 "$BUILD_DIR/launchrights-agent" "$AGENT_BIN"
install -m 755 "$BUILD_DIR/launchrights-menu" "$MENU_BIN"

echo "==> Installing allowlist…"
install -d -m 755 "$SUPPORT_DIR"
if [[ ! -f "$ALLOWLIST" ]]; then
  install -m 644 "$REPO/Resources/allowlist.example.json" "$ALLOWLIST"
  echo "    wrote example allowlist -> $ALLOWLIST (edit before real use)"
else
  echo "    keeping existing $ALLOWLIST"
fi
chown -R root:wheel "$SUPPORT_DIR"

echo "==> Installing launchd jobs…"
install -m 644 "$REPO/Resources/com.jigsaw24.launchrights.helper.plist" "$DAEMON_PLIST"
install -m 644 "$REPO/Resources/com.jigsaw24.launchrights.agent.plist" "$AGENT_PLIST"
install -m 644 "$REPO/Resources/com.jigsaw24.launchrights.menu.plist" "$MENU_PLIST"
chown root:wheel "$DAEMON_PLIST" "$AGENT_PLIST" "$MENU_PLIST"

echo "==> (Re)loading daemon…"
launchctl bootout system "$DAEMON_PLIST" 2>/dev/null || true
launchctl bootstrap system "$DAEMON_PLIST"

echo "==> (Re)loading agent + menu for $CONSOLE_USER (uid $CONSOLE_UID)…"
for p in "$AGENT_PLIST" "$MENU_PLIST"; do
  launchctl bootout "gui/$CONSOLE_UID" "$p" 2>/dev/null || true
  launchctl bootstrap "gui/$CONSOLE_UID" "$p"
done

echo
echo "Done. A lock.shield icon should appear in the menu bar. Tail logs with:"
echo "  sudo tail -f /var/log/launchrightsd.log       # daemon"
echo "  tail -f /tmp/launchrights-agent.log           # launch observer"
echo "  tail -f /tmp/launchrights-menu.log            # menu app"
echo "Audit log (root only): /Library/Application Support/LaunchRights/audit.log"
