# Endpoint Security entitlement — request justification

For Apple's request form at <https://developer.apple.com/contact/request/system-extension/>
(entitlement `com.apple.developer.endpoint-security.client`).

Fill in the bracketed fields. Paste the **Short version** into the form's
description field; keep the rest as supporting detail if a reviewer asks.

---

## Short version (paste into the form)

> Jigsaw24 is an Apple-focused managed service provider. We are building **LaunchRights**,
> a privilege-management agent for macOS fleets that lets standard (non-admin) users
> run a small, IT-approved set of applications with elevated rights — without granting
> them full local administrator accounts.
>
> We need the Endpoint Security client entitlement to subscribe to
> `ES_EVENT_TYPE_AUTH_EXEC` so the agent can intercept the launch of an approved
> application *before* it executes, verify it against a root-owned allowlist and its
> code signature, and relaunch it with elevated privileges. Endpoint Security is the
> only API that provides authorization-time (pre-execution) interception; higher-level
> APIs such as NSWorkspace notifications are post-hoc and cannot gate a launch.
>
> The extension subscribes only to process-execution authorization events. It does not
> read user documents, monitor keystrokes, capture network content, or exfiltrate data.
> It is distributed with Developer ID signing and deployed exclusively to Macs our
> customers own and manage via MDM, with organizational consent. All elevation decisions
> are recorded to a tamper-resistant audit log.
>
> Company: [Jigsaw24 / legal entity] · Team ID: [TEAMID] · App bundle IDs:
> com.jigsaw24.launchrights (host) and com.jigsaw24.launchrights.es (extension).

---

## Supporting detail

**Problem.** On managed Macs, a handful of legitimate business/IT applications require
administrator rights to run (installers, configuration and diagnostic utilities). The
common workaround — making end users local admins — is a significant security risk.
LaunchRights removes that need by elevating only specific, pre-approved applications.

**Why Endpoint Security specifically.**
- We must make an allow/deny decision at process **authorization** time and, for
  approved apps, prevent the unelevated launch and substitute an elevated one. Only
  `ES_EVENT_TYPE_AUTH_EXEC` provides this pre-execution hook.
- Post-hoc notifications (e.g. `NSWorkspace.didLaunchApplicationNotification`) fire
  after the process is already running as the user, forcing a kill-and-relaunch race
  with a visible flash — unacceptable UX and a weaker security boundary. (This is what
  our prototype uses today, precisely because we do not yet hold the entitlement.)

**Events subscribed.** `ES_EVENT_TYPE_AUTH_EXEC` only. No file, keyboard, network, or
screen events. We use the exec message's existing code-signing fields (signing id,
team id) plus an on-disk `SecStaticCode` check to validate the target before elevating.

**Data handling.** No user content is read, stored, or transmitted. The only data
persisted is an audit record per elevation decision (timestamp, requesting user,
target bundle id, outcome), stored root-only on the local device for compliance.

**Distribution & consent.** Developer ID signed and notarized; delivered as a System
Extension inside a host app via MDM (Jamf/Intune/etc.) to devices owned and
administered by our customers. Activation and Full Disk Access are granted by
organizational MDM policy, not covertly.

**Security controls.** The allowlist is root-owned and not user-writable; every
elevation re-verifies the target's code signature against a Team-ID-pinned requirement;
the privileged component validates its XPC callers; all decisions are audited.

**Intended use / out of scope.** LaunchRights is for authorized privilege management of an
organization's own managed Macs. It is not a monitoring, surveillance, DLP, or
anti-malware product, and is not distributed to the general public via the Mac App
Store (Endpoint Security is Developer ID only).
