import Foundation

/// The elevation decision + launch, shared by every privileged component
/// (the XPC daemon and the Endpoint Security daemon). MUST be called from a
/// root context — it spawns the target as whatever uid the caller runs as.
///
/// Every call is audited (launched / denied / failed) via `AuditLog`, so nothing
/// can be elevated without leaving a record.
public enum Launcher {

    public enum Outcome {
        case launched(pid: pid_t, bundleID: String, displayName: String?)
        case denied(String)   // policy said no (not allowlisted / bad signature)
        case failed(String)   // something broke (not a bundle, spawn errno, …)

        public var didLaunch: Bool { if case .launched = self { return true }; return false }

        public var message: String {
            switch self {
            case .launched(let pid, let id, let name): return "launched \(name ?? id) as root (pid \(pid))"
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

        var pid: Int32? { if case .launched(let pid, _, _) = self { return pid }; return nil }
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

        switch spawnAsRoot(executablePath: executableURL.path) {
        case .success(let pid):
            return finish(.launched(pid: pid, bundleID: bundleID, displayName: entry.displayName),
                          bundleID: bundleID, displayName: entry.displayName)
        case .failure(let why):
            return finish(.failed(why), bundleID: bundleID, displayName: entry.displayName)
        }
    }

    private enum SpawnResult { case success(pid_t); case failure(String) }

    private static func spawnAsRoot(executablePath: String) -> SpawnResult {
        var pid: pid_t = 0
        let argv: [UnsafeMutablePointer<CChar>?] = [strdup(executablePath), nil]
        defer { argv.forEach { free($0) } }

        var fileActions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fileActions)
        defer { posix_spawn_file_actions_destroy(&fileActions) }

        let rc = posix_spawn(&pid, executablePath, &fileActions, nil, argv, environ)
        if rc == 0 { return .success(pid) }
        return .failure("posix_spawn failed (errno \(rc): \(String(cString: strerror(rc))))")
    }
}
