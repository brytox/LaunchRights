# LaunchRights for Windows

The Windows port of LaunchRights: let standard (non-admin) users run **specific,
approved** applications with elevated rights — verified by **Authenticode**, logged
for audit, deployable by MDM/Intune. Same idea and the same policy/audit formats as
the macOS build, so one console can manage both fleets.

> **Status: foundation / prototype.** C# / .NET 8. Not yet compiled or run — there
> was no .NET SDK on the authoring machine and it targets Windows-only APIs. Build it
> on Windows with `dotnet build` (VS 2022 or the .NET 8 SDK).

## Architecture — and how it maps to the macOS build

| Windows | Role | macOS counterpart |
|---------|------|-------------------|
| `LaunchRights.Service` (LocalSystem service) | The only component that decides anything: validates + launches elevated | `launchrightsd` (root LaunchDaemon) |
| `LaunchRights.Core` | Allowlist, Authenticode check, launcher, audit log, IPC contract | `LaunchRightsShared` |
| Named pipe `\\.\pipe\LaunchRights` | Request/response transport | XPC Mach service |
| `Authenticode.Verify` (WinVerifyTrust + signer cert) | On-disk signature check | `CodeSigning.validateOnDisk` |
| `Launcher` (CreateProcessAsUser into the user session) | Runs the app elevated | `Launcher` (posix_spawn as root) |
| `LaunchRights.Run` (CLI) | User-facing trigger — "run this approved app elevated" | menu "launch elevated" / manual path |
| `LaunchRights.Agent` (WMI process-start observer) | Auto-detect a launch → relaunch elevated | `launchrights-agent` (NSWorkspace observer) |
| `LaunchRights.Tray` (WinForms NotifyIcon) | Status + approved apps + recent elevations + manual run | `launchrights-menu` |
| *(future)* kernel process-notify driver | Pre-exec interception, no flash | Endpoint Security extension |

The pipe carries three commands — `ping` / `recent` / `elevate` — mirroring the mac
`HelperProtocol` (`ping` / `recentEvents` / `launchElevated`). The tray uses all three;
`recent` lets the unprivileged UI show the SYSTEM-only audit log via the service.

`%ProgramData%\LaunchRights\allowlist.json` and `audit.log` are the Windows analogues
of the mac `/Library/Application Support/LaunchRights` files.

## What works in this drop

- **Service + `LaunchRights.Run`** is the end-to-end path: a standard user runs
  `LaunchRights.Run <id-or-path>`, the service re-validates against the allowlist +
  Authenticode and launches the app elevated, and the decision is audited.
- **`LaunchRights.Tray`** gives users a notification-area menu: service status, the
  approved-apps list (click to run elevated), and recent elevations. Installed to
  auto-start at logon.
- **`LaunchRights.Agent`** is the experimental auto-interception layer (detect →
  relaunch), mirroring the mac observer prototype.

## Build & install

```powershell
# from the windows\ folder, in an elevated PowerShell (needs .NET 8 SDK)
dotnet build LaunchRights.sln -c Release
.\scripts\install-service.ps1        # publishes, ACLs ProgramData, registers + starts the service
```

Then, as a standard user:

```powershell
& "$env:ProgramFiles\LaunchRights\LaunchRights.Run.exe" com.corp.NetConfig
# or a full path:
& "$env:ProgramFiles\LaunchRights\LaunchRights.Run.exe" "C:\Program Files\NetConfig\NetConfig.exe"
```

Wire `LaunchRights.Run` to a per-app Start-menu shortcut or a right-click
"Run with LaunchRights" shell verb for a double-click-style experience.

Uninstall: `.\scripts\uninstall-service.ps1`.

## Allowlist

Same shape as macOS, with a Windows signature pin instead of a codesign requirement:

```json
{
  "apps": [
    {
      "id": "com.corp.NetConfig",
      "displayName": "Net Config",
      "path": "C:\\Program Files\\NetConfig\\NetConfig.exe",
      "publisher": "O=Contoso Ltd",
      "thumbprint": "A1B2C3…"
    }
  ]
}
```

- `path` — the image matched at launch (normalized, case-insensitive).
- `thumbprint` — SHA-1 signer thumbprint pin (strongest). / `publisher` — required
  substring of the signer subject. Provide at least one; both empty = **insecure**,
  skips verification (prototype only).

## Security model

Same principles as the mac build:

1. **The service owns the allowlist**, in an ACL'd `%ProgramData%` path a standard
   user can read but not write. The installer sets the ACL; `audit.log` is
   SYSTEM/Administrators only.
2. **Authenticode re-verified at launch** against a thumbprint/publisher pin — a
   swapped or unsigned binary is refused.
3. **Every decision audited** (`launched` / `denied` / `failed`) with the caller's
   identity, in the same JSON-lines format as macOS.

### Known prototype limitations / roadmap

- **Elevation identity.** The launcher now prefers the interactive user's own
  **elevated token**: if they're an administrator (protected-admin under UAC), it uses
  their *linked elevated token* so the app runs **as them**, elevated, with their
  profile/HKCU — the correct path. Only for a **true standard user** (no admin token to
  grant) does it fall back to **LocalSystem in the user's session**. The identity used is
  written to the audit log. Making a *standard* user's app run as themselves-with-admin
  needs temporary Administrators-group membership or an LSA/driver token minter — both
  are larger efforts and remain on the roadmap.
- **Peer verification:** the pipe currently trusts any authenticated caller (and
  audits them). Harden with `GetNamedPipeClientProcessId` + Authenticode-verify the
  caller is our signed `Run`/`Agent` — the analogue of the mac XPC peer check.
- **Auto-interception** uses WMI polling (detect → kill → relaunch, a brief flash) and
  typically needs to run elevated to receive events. Production path: a signed kernel
  **process-creation callback** (`PsSetCreateProcessNotifyRoutineEx`) for true pre-exec
  gating — the Windows equivalent of (and signing hurdle of) the mac ES extension.
- **Tray app** (`LaunchRights.Tray`) is a WinForms NotifyIcon prototype (status +
  approved apps + recent elevations + manual run). A richer WinUI 3 version with a
  proper window is a possible upgrade; the current one uses `SystemIcons.Shield` as a
  placeholder — drop in a branded `.ico`.
- **MDM:** ship the service via Intune (Win32 app) and the allowlist via a
  configuration profile / policy, mirroring the mac MDM story.
