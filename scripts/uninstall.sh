#!/bin/bash
# Remove LaunchRights. Requires sudo.  sudo ./scripts/uninstall.sh
set -uo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "error: run with sudo" >&2
  exit 1
fi

CONSOLE_USER="$(stat -f%Su /dev/console)"
CONSOLE_UID="$(id -u "$CONSOLE_USER")"

DAEMON_PLIST="/Library/LaunchDaemons/com.jigsaw24.launchrights.helper.plist"
AGENT_PLIST="/Library/LaunchAgents/com.jigsaw24.launchrights.agent.plist"
MENU_PLIST="/Library/LaunchAgents/com.jigsaw24.launchrights.menu.plist"

echo "==> Unloading launchd jobs…"
launchctl bootout "gui/$CONSOLE_UID" "$AGENT_PLIST" 2>/dev/null || true
launchctl bootout "gui/$CONSOLE_UID" "$MENU_PLIST" 2>/dev/null || true
launchctl bootout system "$DAEMON_PLIST" 2>/dev/null || true

echo "==> Removing files…"
rm -f "$DAEMON_PLIST" "$AGENT_PLIST" "$MENU_PLIST"
rm -f /usr/local/libexec/launchrightsd /usr/local/bin/launchrights-agent /usr/local/bin/launchrights-menu

echo "    (leaving /Library/Application Support/LaunchRights and its allowlist in place)"
echo "Done."
