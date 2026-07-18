# LaunchRights — MDM deployment profiles

`LaunchRights.mobileconfig` makes activation **silent** on managed Macs — no user
prompts to allow the extension or grant Full Disk Access. Without it, each user
would have to approve the system extension in System Settings and toggle FDA
manually.

## What's in it

| Payload | Type | Effect |
|---------|------|--------|
| Allowed System Extensions | `com.apple.system-extension-policy` | pre-approves `com.jigsaw24.launchrights.es`, so it loads without the "System Extension Blocked" prompt |
| Privacy (PPPC) | `com.apple.TCC.configuration-profile-policy` | grants the ES extension **Full Disk Access** (`SystemPolicyAllFiles`) — Endpoint Security clients require it, else `es_new_client` returns `NOT_PERMITTED` |

## Before deploying — required edits

1. **Team ID:** replace every `ABCDE12345` with your real Team ID (two places — the
   `AllowedSystemExtensions` key and the PPPC `CodeRequirement`).
2. **CodeRequirement:** confirm it matches how the extension is actually signed:
   ```
   codesign -dr - /Applications/LaunchRights.app/Contents/Library/SystemExtensions/com.jigsaw24.launchrights.es.systemextension
   ```
   Paste the printed designated requirement into the `CodeRequirement` value if it
   differs from the pinned form here.

## Deploy

- **Jamf Pro:** Computers ▸ Configuration Profiles ▸ Upload → scope to the target
  Macs. (Jamf also has native "System Extensions" and "PPPC" payload editors if you
  prefer building it in the UI instead of importing.)
- **Intune:** Devices ▸ macOS ▸ Configuration ▸ Custom profile → upload the
  `.mobileconfig`.
- **Other MDM:** import as a custom/raw configuration profile. MDMs typically
  re-issue the `PayloadUUID`s on upload — expected.

The profile is **device-scoped** (`PayloadScope: System`) and must be delivered by
MDM — the PPPC payload is only honoured when installed by an MDM the Mac is enrolled
in (a manually-installed PPPC profile is ignored by macOS by design).

## Order of operations

1. Push this profile to the fleet.
2. Deploy `LaunchRights.app` to `/Applications` (via your MDM's app/pkg workflow).
3. Launch it (or let it launch at login) — the extension activates silently and
   already has Full Disk Access.

## Standalone (non-sysext) daemon

If you deploy the wrapped-bundle LaunchDaemon (`scripts/package-es.sh`) instead of
the system extension, you don't need the System Extension payload — but you **do**
still need the PPPC Full Disk Access payload, targeting the daemon's code
requirement (same `CodeRequirement` as above).
