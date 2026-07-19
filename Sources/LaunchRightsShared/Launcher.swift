import Foundation
import CLaunchRightsSession

/// The elevation decision + launch, shared by every privileged component
/// (the XPC daemon and the Endpoint Security daemon). MUST be called from a
/// root context — it spawns the target as whatever uid the caller runs as.
///
/// Every call is audited (launched / denied / failed) via `AuditLog`, so nothing
/// can be elevated without leaving a record.
public enum Launcher {

    public enum Outcome {
        case launched(pid: pid_t, bundleID: String, displayName: String?, user: String)
        case denied(String)   // policy said no (not allowlisted / bad signature)
        case failed(String)   // something broke (not a bundle, spawn errno, …)

        public var didLaunch: Bool { if case .launched = self { return true }; return false }

        public var message: String {
            switch self {
            case .launched(let pid, let id, let name, let user):
                return "launched \(name ?? id) as \(user) (pid \(pid))"
            case .denied(let why): return "denied: \(why)"
            case .failed(let why): return "failed: \(why)"
            }
        }

        var auditVerb: String {
            switch self {
            case .launched: return "launched"
            case .denied:   return "denied"
            case .failed:   return "failed"
            }
        }

        var pid: Int32? { if case .launched(let pid, _, _, _) = self { return pid }; return nil }
    }

    /// Validate `bundlePath` against the allowlist + its code signature, and if it
    /// passes, launch it (as root, since the daemon is root). Records the outcome.
    ///
    /// `bundlePath` is UNTRUSTED — the caller only points at an app; every trust
    /// decision is re-made here against the root-owned allowlist.
    public static func elevate(bundlePath: String,
                               allowlist: Allowlist,
                               context: ElevationContext,
                               log: (String) -> Void = { _ in }) -> Outcome {

        func finish(_ outcome: Outcome, bundleID: String?, displayName: String?) -> Outcome {
            AuditLog.record(AuditRecord(
                timestamp: AuditLog.now(),
                source: context.source,
                requestingUID: UInt32(context.requestingUID),
                requestingUser: SystemInfo.username(forUID: context.requestingUID),
                outcome: outcome.auditVerb,
                bundleID: bundleID,
                displayName: displayName,
                bundlePath: bundlePath,
                pid: outcome.pid,
                message: outcome.message))
            return outcome
        }

        guard let bundle = Bundle(path: bundlePath) else {
            return finish(.failed("not a bundle: \(bundlePath)"), bundleID: nil, displayName: nil)
        }
        guard let bundleID = bundle.bundleIdentifier else {
            return finish(.failed("bundle has no identifier: \(bundlePath)"), bundleID: nil, displayName: nil)
        }
        guard let executableURL = bundle.executableURL else {
            return finish(.failed("bundle has no executable: \(bundlePath)"), bundleID: bundleID, displayName: nil)
        }

        guard let entry = allowlist.entry(forBundleIdentifier: bundleID) else {
            return finish(.denied("not allowlisted: \(bundleID)"), bundleID: bundleID, displayName: nil)
        }

        // The load-bearing control: re-verify the on-disk signature.
        if entry.requirement.isEmpty {
            log("WARNING: elevating \(bundleID) with NO signature requirement (insecure)")
        } else if !CodeSigning.validateOnDisk(path: bundlePath, requirement: entry.requirement) {
            return finish(.denied("signature check failed: \(bundleID)"),
                          bundleID: bundleID, displayName: entry.displayName)
        }

        // Who to run as. Absent / "root" → root (today's behaviour). Any other
        // value is a local account we drop privileges to.
        let runAsUser = (entry.runAs?.isEmpty == false) ? entry.runAs! : "root"
        if runAsUser != "root" {
            guard getpwnam(runAsUser) != nil else {
                return finish(.failed("unknown runAs user: \(runAsUser)"),
                              bundleID: bundleID, displayName: entry.displayName)
            }
            // A GUI app can't reach the console user's WindowServer as a non-root
            // user, so it will run headless. Flag it — silent no-window is worse.
            log("note: running \(bundleID) as '\(runAsUser)' (not root); if it is a GUI app it will not show a window")
        }

        switch spawnElevated(executablePath: executableURL.path,
                             auditSessionID: context.auditSessionID,
                             runAsUser: runAsUser) {
        case .success(let pid):
            return finish(.launched(pid: pid, bundleID: bundleID,
                                    displayName: entry.displayName, user: runAsUser),
                          bundleID: bundleID, displayName: entry.displayName)
        case .failure(let why):
            return finish(.failed(why), bundleID: bundleID, displayName: entry.displayName)
        }
    }

    private enum SpawnResult { case success(pid_t); case failure(String) }

    /// Launch the target joined to `auditSessionID`'s login session, optionally
    /// dropping from root to `runAsUser`. `auditSessionID <= 0` degrades to a
    /// plain fork/exec; `runAsUser == "root"` keeps full privilege (the only
    /// value that reliably shows a GUI window).
    private static func spawnElevated(executablePath: String,
                                      auditSessionID: Int32,
                                      runAsUser: String) -> SpawnResult {
        let argv: [UnsafeMutablePointer<CChar>?] = [strdup(executablePath), nil]
        defer { argv.forEach { free($0) } }

        var err: Int32 = 0
        // "root" → NULL so the shim stays root; otherwise it drops to the user.
        let pid: pid_t = runAsUser == "root"
            ? lr_spawn_elevated(executablePath, argv, auditSessionID, nil, &err)
            : runAsUser.withCString { lr_spawn_elevated(executablePath, argv, auditSessionID, $0, &err) }
        if pid > 0 { return .success(pid) }
        return .failure("spawn failed (errno \(err): \(String(cString: strerror(err))))")
    }
}
