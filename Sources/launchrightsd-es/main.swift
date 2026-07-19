import Foundation
import EndpointSecurity
import LaunchRightsShared

/// launchrightsd-es — the Endpoint Security flavour.
///
/// A single root daemon. It subscribes to AUTH_EXEC and, when a standard user is
/// about to launch an allowlisted app, DENIES that user-context exec and relaunches
/// the app as root itself. No per-user agent, no XPC, no launch-flash.
///
/// Requirements to run:
///   • root
///   • EITHER the `com.apple.developer.endpoint-security.client` entitlement on a
///     properly Developer ID-signed binary, OR SIP disabled (dev boxes only).
///   • sometimes Full Disk Access for the running binary/terminal (TCC).
///
/// This is the production-shaped interceptor; the trust logic (allowlist + on-disk
/// signature) is the same `Launcher` the XPC prototype uses.

// MARK: - Config / logging

func logLine(_ message: String) { NSLog("launchrightsd-es: \(message)") }

let allowlistPath = ProcessInfo.processInfo.environment["LAUNCHRIGHTS_ALLOWLIST"]
    ?? LaunchRightsNames.allowlistPath

// Loaded once at startup. Restart (or send SIGHUP, see below) to pick up edits.
var allowlist = Allowlist.load(from: allowlistPath)
var allowlistedIDs = Set(allowlist.apps.map { $0.bundleIdentifier })

// Serialises the (async) elevated relaunch off the ES callback thread.
let elevationQueue = DispatchQueue(label: "com.jigsaw24.launchrights.elevate")

// MARK: - Helpers

/// Decode an es_string_token_t (not necessarily NUL-terminated) into a String.
func esString(_ token: es_string_token_t) -> String {
    guard token.length > 0, let ptr = token.data else { return "" }
    return String(decoding: UnsafeRawBufferPointer(start: ptr, count: token.length), as: UTF8.self)
}

/// `.../Foo.app/Contents/MacOS/Foo` -> `.../Foo.app`
func appBundlePath(fromExecutable exe: String) -> String? {
    var url = URL(fileURLWithPath: exe)
    for _ in 0..<3 { url.deleteLastPathComponent() }   // exe, MacOS, Contents
    return url.pathExtension == "app" ? url.path : nil
}

/// euid of the process performing the exec. audit_token_t is `unsigned int[8]`,
/// imported as an 8-tuple; euid is index 1 (matches audit_token_to_euid()).
func euid(of token: audit_token_t) -> uid_t { token.val.1 }

/// Audit session id of the process performing the exec; index 6 matches
/// audit_token_to_asid(). This is the user's login/GUI session — we join the
/// elevated relaunch to it so its window appears on the right display.
func asid(of token: audit_token_t) -> Int32 { Int32(bitPattern: token.val.6) }

// MARK: - AUTH_EXEC handler

// Every AUTH message MUST be answered before its deadline or ES may kill us, so
// each path responds exactly once, fast; the actual relaunch happens async.
let handler: (OpaquePointer, UnsafePointer<es_message_t>) -> Void = { client, msgPtr in
    let msg = msgPtr.pointee
    let exec = msg.event.exec
    let target = exec.target.pointee

    let exePath = esString(target.executable.pointee.path)
    let signingID = esString(target.signing_id)          // ≈ CFBundleIdentifier for signed apps
    let initiatorEUID = euid(of: msg.process.pointee.audit_token)
    let initiatorASID = asid(of: msg.process.pointee.audit_token)

    @inline(__always) func allow() { es_respond_auth_result(client, msgPtr, ES_AUTH_RESULT_ALLOW, false) }
    @inline(__always) func deny()  { es_respond_auth_result(client, msgPtr, ES_AUTH_RESULT_DENY, false) }

    // Loop-breaker: our own root relaunch (and anything already privileged) passes
    // straight through — we never intercept root-initiated execs.
    if initiatorEUID == 0 { allow(); return }

    // Fast path: not an app we manage.
    guard allowlistedIDs.contains(signingID) else { allow(); return }

    guard let bundlePath = appBundlePath(fromExecutable: exePath) else {
        logLine("could not derive .app for \(exePath); allowing unelevated")
        allow(); return
    }

    // Block the user-context launch now; relaunch elevated out of band.
    deny()
    let snapshot = allowlist
    let context = ElevationContext(requestingUID: initiatorEUID, source: "es",
                                   auditSessionID: initiatorASID)
    elevationQueue.async {
        let outcome = Launcher.elevate(bundlePath: bundlePath, allowlist: snapshot,
                                       context: context, log: { logLine($0) })
        logLine("\(signingID): \(outcome.message)")
    }
}

// MARK: - Bring up the client

var client: OpaquePointer?
let newClientResult = es_new_client(&client, handler)

guard newClientResult == ES_NEW_CLIENT_RESULT_SUCCESS, let esClient = client else {
    let reason: String
    switch newClientResult {
    case ES_NEW_CLIENT_RESULT_ERR_NOT_ENTITLED:
        reason = "not entitled — sign with com.apple.developer.endpoint-security.client, or disable SIP for dev"
    case ES_NEW_CLIENT_RESULT_ERR_NOT_PERMITTED:
        reason = "not permitted — grant Full Disk Access (TCC) to this binary/terminal"
    case ES_NEW_CLIENT_RESULT_ERR_NOT_PRIVILEGED:
        reason = "not privileged — run as root (sudo)"
    case ES_NEW_CLIENT_RESULT_ERR_TOO_MANY_CLIENTS:
        reason = "too many ES clients"
    default:
        reason = "es_new_client failed (code \(newClientResult.rawValue))"
    }
    logLine("FATAL: \(reason)")
    exit(1)
}

var events = [ES_EVENT_TYPE_AUTH_EXEC]
guard es_subscribe(esClient, &events, UInt32(events.count)) == ES_RETURN_SUCCESS else {
    logLine("FATAL: es_subscribe failed")
    es_delete_client(esClient)
    exit(1)
}

// Live allowlist reload on SIGHUP (avoids restart-to-edit).
let sighup = DispatchSource.makeSignalSource(signal: SIGHUP, queue: .main)
sighup.setEventHandler {
    allowlist = Allowlist.load(from: allowlistPath)
    allowlistedIDs = Set(allowlist.apps.map { $0.bundleIdentifier })
    logLine("allowlist reloaded: \(allowlistedIDs.count) app(s)")
}
sighup.resume()
signal(SIGHUP, SIG_IGN)

// XPC surface for the menu app (status / recent elevations / manual launch).
// Only routes connections when installed under launchd with the MachServices key
// declared (com.jigsaw24.launchrights.es.plist); a bare foreground dev run gets none.
let xpc = HelperService(daemonName: "launchrightsd-es", log: { logLine($0) })
xpc.resume()

logLine("started; watching AUTH_EXEC for \(allowlistedIDs.count) allowlisted app(s) from \(allowlistPath)")
dispatchMain()
