#!/bin/bash
# Provision the hidden admin SERVICE ACCOUNT that allowlist entries can target
# via "runAs". Apps run AS this account get admin-group privileges WITHOUT the
# human ever holding its credentials — the root daemon switches to it with no
# password (root can setuid to anyone), so the password below is random and
# discarded purely to block interactive login.
#
#   sudo ./scripts/create-service-account.sh
#
# Idempotent: re-running just re-asserts the account's settings.
#
# NOTE: a GUI app run as this account will NOT show a window (macOS restricts a
# login session's WindowServer to its owning user or root). Use "runAs" for
# command-line / admin-task apps; keep GUI apps on the default (root).
set -euo pipefail

ACCOUNT="${LAUNCHRIGHTS_SERVICE_ACCOUNT:-_launchrights}"
FULLNAME="LaunchRights Service"
HOMEDIR="/var/${ACCOUNT}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "error: run with sudo" >&2
  exit 1
fi

if id "$ACCOUNT" >/dev/null 2>&1; then
  echo "==> Account '$ACCOUNT' already exists — re-asserting settings."
else
  echo "==> Creating hidden admin account '$ACCOUNT'…"
  # A random password nobody records; the daemon never needs it.
  RANDPW="$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32 || true)"
  sysadminctl -addUser "$ACCOUNT" \
              -fullName "$FULLNAME" \
              -password "$RANDPW" \
              -home "$HOMEDIR" \
              -admin 2>&1 | sed 's/^/    /'
  unset RANDPW
fi

echo "==> Hardening (hidden, admin group, home present)…"
# Keep it off the login window / user list.
dscl . -create "/Users/$ACCOUNT" IsHidden 1
# Ensure admin group membership (sysadminctl -admin should have done this).
dseditgroup -o edit -a "$ACCOUNT" -t user admin 2>/dev/null || true
# Make sure a home dir exists (some CLI tools expect $HOME to be writable).
if [[ ! -d "$HOMEDIR" ]]; then
  install -d -m 700 "$HOMEDIR"
  chown "$ACCOUNT" "$HOMEDIR"
fi

echo
echo "Done. Reference it from an allowlist entry:"
echo '    { "bundleIdentifier": "...", "requirement": "...", "runAs": "'"$ACCOUNT"'" }'
echo
echo "Verify:"
echo "    id $ACCOUNT                       # should list the 'admin' group (gid 80)"
echo "    dscl . -read /Users/$ACCOUNT IsHidden"
echo
echo "Remove later with:"
echo "    sudo sysadminctl -deleteUser $ACCOUNT"
