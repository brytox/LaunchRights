# LaunchRights

Let standard (non-admin) macOS users run **specific, approved** apps with elevated
(root) rights — without giving them full admin on the machine. When a user
double-clicks an allowlisted app, it comes back up elevated; everything else runs
normally.

This is the same category of tool as SAP Privileges or MDM privilege-management
features, but scoped **per-app** rather than promoting the whole account.

> **Status: prototype.** Ad-hoc signed, manual install. See
> [Path to production](#path-to-production) for what changes before real use.

## Two flavours

| Flavour | Target(s) | Interception | Needs | Best for |
|---------|-----------|--------------|-------|----------|
| **XPC prototype** | `launchrightsd` + `launchrights-agent` | launch → detect → relaunch (brief flash) | nothing special; ad-hoc OK | building/testing the logic today |
| **Endpoint Security** | `launchrightsd-es` (single root daemon) | pre-exec, no flash | ES entitlement **or** SIP off; root | production shape |

Both share the same trust core (`LaunchRightsShared` → allowlist + on-disk signature +
`Launcher`). Pick one at deploy time. The sections below cover the XPC prototype
first, then the ES flavour.

## How it works

```
 user double-clicks an approved app
        │
        ▼
 app starts normally (as the standard user)
        │
        ▼
 launchrights-agent (per-user LaunchAgent) sees the launch
   • is the bundle id on the allowlist?
   • is this instance already root?  ── yes ──▶ leave it alone (loop-breaker)
        │ no
        ▼
 agent kills the user instance, asks the daemon over XPC to elevate it
        │
        ▼
 launchrightsd (root LaunchDaemon) — the ONLY component that decides anything
   • re-reads the bundle id from disk
   • matches it against the root-owned allowlist
   • re-verifies the app's on-disk CODE SIGNATURE against the allowlist rule
   • launches the app as root
```

**All trust lives in the root daemon.** The agent never runs anything itself and
its requests are treated as untrusted — it only *points at* an app; the daemon
independently re-validates everything before elevating.

### Components

| Component        | Runs as        | Role |
|------------------|----------------|------|
| `launchrightsd`      | root (LaunchDaemon) | XPC service; owns allowlist + signature checks; launches apps elevated; serves audit log to the UI |
| `launchrightsd-es`   | root (LaunchDaemon) | Endpoint Security flavour — single daemon, pre-exec interception |
| `launchrights-agent` | logged-in user (LaunchAgent) | XPC-flavour launch observer; requests elevation |
| `launchrights-menu`  | logged-in user (LaunchAgent) | menu-bar control panel: allowlist + recent elevations + manual launch |
| `LaunchRightsShared` | —              | allowlist model, code-signing, `Launcher`, audit log — shared by all |
| allowlist.json   | root-owned     | `/Library/Application Support/LaunchRights/allowlist.json` |
| audit.log        | root-only (0600) | `/Library/Application Support/LaunchRights/audit.log` |

## Security model (read this)

This is a **local privilege-escalation mechanism**. Done wrong it's a root exploit.
The controls that matter:

1. **The daemon owns the allowlist.** It lives in a root-writable directory. A
   standard user cannot add apps to it.
2. **Signature is re-checked at launch, on disk.** Matching by bundle id alone is
   not enough — an attacker could drop a malicious app with the same id. Each
   allowlist entry carries a Code Signing Requirement (Team ID / anchor) the app
   must satisfy *before* it's elevated.
3. **The caller is verified.** The daemon checks the connecting agent against a
   signing requirement (`LAUNCHRIGHTS_AGENT_REQ`) so arbitrary user processes can't
   ask it to elevate things.

### Known prototype limitations

- **Peer check is by PID**, which is theoretically race-able (PID reuse). Production
  uses the XPC connection's *audit token* instead. (`CodeSigning.validatePeer`)
- **TOCTOU window** between the signature check and `posix_spawn`. Narrow, but real;
  production should hold a validated `SecStaticCode` reference / launch by inode.
- **GUI-as-root in the Aqua session** is restricted on modern macOS. The prototype
  reliably runs the target *as root* (verify below), but a full GUI app may not
  render in the user's session purely from a root daemon spawn. This is best shown
  today with CLI/utility "admin tools"; production approaches this via the ES flow
  and/or per-app relaunch into the user session with elevated capability.
- **`LAUNCHRIGHTS_AGENT_REQ` and per-app `requirement` empty = checks skipped.** Only
  for the first local run. Never ship empty.

## Build & install (prototype)

```bash
swift build -c release          # compile
sudo ./scripts/install.sh       # install daemon + agent + example allowlist
```

The installer builds, copies binaries to `/usr/local/{libexec,bin}`, installs the
launchd plists, drops an example allowlist, and bootstraps both jobs.

### Verify it's working

```bash
sudo tail -f /var/log/launchrightsd.log      # daemon log
tail -f /tmp/launchrights-agent.log          # agent log
```

The agent logs `daemon says: launchrightsd alive…` on start (XPC round-trip works).
Then launch an allowlisted app and confirm it's running as root:

```bash
ps -o user,pid,comm -p "$(pgrep -n <appname>)"
# USER should be 'root'
```

Edit the allowlist and restart the daemon to pick it up:

```bash
sudo vim "/Library/Application Support/LaunchRights/allowlist.json"
sudo launchctl kickstart -k system/com.jigsaw24.launchrights.helper
```

### Uninstall

```bash
sudo ./scripts/uninstall.sh
```

## Endpoint Security flavour (`launchrightsd-es`)

Same idea, done properly: one root daemon subscribes to `ES_EVENT_TYPE_AUTH_EXEC`.
When a standard user is about to launch an allowlisted app, it **denies that
user-context exec and relaunches the app as root itself** — no per-user agent, no
XPC, no launch-flash. It reuses the exact same `Launcher` trust logic.

Loop-breaker: root-initiated execs (including its own relaunch) are always allowed
through untouched, so the elevated instance isn't re-intercepted.

It also exposes the **same XPC surface** as the XPC flavour (via the shared
`HelperService` on `com.jigsaw24.launchrights.helper`), so the menu app shows live
status + recent elevations against either daemon with no changes. This only routes
when installed under launchd (the `MachServices` key is in the plist) — a bare
foreground dev run still intercepts fine but serves no XPC.

### Requirements

- Runs as **root**.
- Needs **either** the `com.apple.developer.endpoint-security.client` entitlement on
  a Developer ID-signed binary, **or** **SIP disabled** (dev boxes only).
- May need **Full Disk Access** (TCC) for the binary/terminal — the daemon prints a
  precise reason if `es_new_client` is refused.

### Dev loop (SIP-off box)

```bash
csrutil status                                   # must say "disabled" for ad-hoc dev
sudo cp Resources/allowlist.example.json "/Library/Application Support/LaunchRights/allowlist.json"
./scripts/run-es-dev.sh                           # builds + runs the daemon in the foreground
```

Then double-click an allowlisted app: the daemon logs the DENY + the elevated
relaunch, and `ps -o user -p <pid>` shows `root`. Edit the allowlist live and
`sudo killall -HUP launchrightsd-es` to reload without restarting.

### Known ES caveats

- **Denying a GUI app's exec can surface a Finder error** ("app quit unexpectedly")
  before the elevated instance appears. Tuning: relaunch faster, or suppress via the
  host-app UX. CLI/utility admin tools are cleanest.
- **Matching is by `signing_id`** (the code-signing identifier, ≈ `CFBundleIdentifier`
  for signed apps). Apps whose signing id differs from their bundle id won't match;
  add a bundle-id fallback if you hit this.
- **Subscribes to all execs.** Fine for a prototype; production should `es_mute_path`
  the noise to cut overhead.

### Persistent install

Once entitled + signed (or on a SIP-off box), install `launchrightsd-es` to
`/usr/local/libexec/` and load `Resources/com.jigsaw24.launchrights.es.plist` as a
LaunchDaemon (same pattern as the XPC installer). Don't run both flavours at once.

## Requesting the ES entitlement

The entitlement is the long pole. A ready-to-paste justification for Apple's request
form (with company/Team-ID blanks to fill in) is in `ENTITLEMENT_JUSTIFICATION.md`.

## Signing & the ES entitlement

A **naked command-line tool cannot use the Endpoint Security entitlement** when SIP
is on: the entitlement must be whitelisted by an *embedded provisioning profile*,
and only a bundle can carry one. So for real (SIP-on) use, `launchrightsd-es` is wrapped
in a minimal signed `.app` bundle that holds `Contents/embedded.provisionprofile`.
The LaunchDaemon's `Program` then points at the executable **inside** that bundle.

Files:
- `Resources/launchrightsd-es.entitlements` — `com.apple.developer.endpoint-security.client`.
- `Resources/LaunchRightsES-Info.plist` — bundle Info.plist (its `CFBundleIdentifier`
  must match the App ID your profile is for).
- `Resources/com.jigsaw24.launchrights.es-signed.plist` — daemon plist pointing into
  the installed bundle.
- `scripts/package-es.sh` — build → assemble bundle → embed profile → sign → verify.
- `scripts/notarize-es.sh` — notarize + staple for distribution to other Macs.

### After Apple grants the entitlement

1. **Portal → App ID** `com.jigsaw24.launchrights.es`: enable **Endpoint Security**
   (and **System Extension** if you go the sysext route). Match the Info.plist id.
2. **Portal → Provisioning profile** for that App ID, including the ES capability;
   download the `.provisionprofile`.
3. Build + sign the bundle:
   ```bash
   export DEV_ID_APP="Developer ID Application: Your Org (TEAMID)"
   export PROVISION_PROFILE=~/Downloads/LaunchRightsES.provisionprofile
   ./scripts/package-es.sh          # prints the install commands
   ```
4. Distribute to other Macs (Gatekeeper): `./scripts/notarize-es.sh`.

**Local test shortcut:** on *this* registered Mac you can skip Developer ID +
notarization — use the **Apple Development** identity plus a **development**
provisioning profile that includes the ES capability (device registered). Pass that
identity as `DEV_ID_APP` and the development profile as `PROVISION_PROFILE`. Once
signed with a profile that whitelists the entitlement, `launchrightsd-es` loads with SIP
**on** — no more `csrutil disable`.

Once binaries are Developer ID-signed, also pin the XPC peer check: set
`LAUNCHRIGHTS_AGENT_REQ` in the daemon plist to
`anchor apple generic and certificate leaf[subject.OU] = "TEAMID"`.

## Auditing

Every elevation decision — **launched, denied, or failed** — is recorded by the
shared `Launcher`, so nothing reaches root without a record, in **either** flavour.

- Written to `/Library/Application Support/LaunchRights/audit.log` as one JSON object
  per line (`LAUNCHRIGHTS_AUDIT` overrides the path for dev).
- Created **0600, root-only** — standard users can't read who-ran-what or tamper
  with the trail.
- Each record: timestamp, source (`es`/`xpc`), requesting uid + username, outcome,
  bundle id, display name, bundle path, resulting pid, and a message.

Because the file is root-only, the unprivileged menu app never opens it directly —
it asks the daemon over XPC (`recentEvents`), which reads and formats it. For
production, ship these off-box (unified logging / MDM log collection / SIEM).

## Control-panel app (`launchrights-menu`)

A menu-bar (accessory) app — the `lock.shield` icon. It talks to whichever daemon
is installed (XPC or ES — both serve the same `HelperService`). It:

- shows **daemon status** (from `ping` — e.g. "launchrightsd-es alive, uid=0", or
  "daemon not running"),
- lists the current **approved apps**,
- shows **recent elevations** (fetched from the daemon over XPC),
- offers a manual **"launch elevated"** action per app (handy with the XPC flavour;
  with the ES flavour, launching is automatic on double-click).

It's also the natural home for the **ES System Extension host** later: the app that
calls `OSSystemExtensionRequest` to activate/deactivate `launchrightsd-es` lives here.

## Path to production

1. **Get the ES daemon (`launchrightsd-es`, done) entitled + signed.** The interceptor
   is built and the signing scaffold is ready (see *Signing & the ES entitlement*).
   Entitlement is requested; once granted, `package-es.sh` / `notarize-es.sh` do the
   rest. Two shapes are scaffolded:
   - **Wrapped-bundle LaunchDaemon** — `scripts/package-es.sh` (simplest).
   - **System Extension** — `SystemExtension/` (XcodeGen project: `launchrights-menu`
     grown into a host app that embeds + activates the ES sysext via
     `OSSystemExtensionRequest`). Fully Apple-supported and MDM-friendly. See
     `SystemExtension/README.md`.
2. **Ship via `SMAppService`** (macOS 13+) or MDM, not a sudo script. Requires
   Developer ID signing + notarization.
3. **Audit-token peer validation** (XPC flavour only — replace the PID check).
4. **MDM rollout:** push the approval profile (`MDM/LaunchRights.mobileconfig` —
   System Extension allow policy + PPPC Full Disk Access) and the allowlist via
   Jamf/Intune/Addigy so nothing needs per-machine user approval. See `MDM/README.md`.
5. **Auditing:** log every elevation (who, what, signature, timestamp) to a
   tamper-resistant store for compliance.
