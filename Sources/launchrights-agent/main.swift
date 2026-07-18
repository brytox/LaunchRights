import Foundation
import AppKit
import LaunchRightsShared

/// launchrights-agent — the per-user launch observer.
///
/// Runs as the logged-in (standard, non-admin) user via a LaunchAgent. It watches
/// for app launches and, when an allowlisted app starts as the normal user, asks
/// the root daemon to relaunch it elevated.
///
/// This observer is the deliberately-swappable component: in production you would
/// replace `NSWorkspace.didLaunchApplicationNotification` with an Endpoint Security
/// client that intercepts `ES_EVENT_TYPE_AUTH_EXEC` *before* the process runs. The
/// daemon and its trust checks stay exactly the same.

func log(_ message: String) {
    NSLog("launchrights-agent: \(message)")
}

/// Return the owning uid of a running process, or nil if it can't be determined.
/// Used to avoid an infinite loop: once the daemon relaunches the app as root, the
/// same launch notification fires again — we must recognise the root instance and
/// leave it alone.
func uid(forPID pid: pid_t) -> uid_t? {
    var info = kinfo_proc()
    var size = MemoryLayout<kinfo_proc>.stride
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
    let rc = sysctl(&mib, 4, &info, &size, nil, 0)
    if rc != 0 || size == 0 { return nil }
    return info.kp_eproc.e_ucred.cr_uid
}

final class Agent {
    private let connection: NSXPCConnection
    private var allowlistedBundleIDs: Set<String> = []

    init() {
        connection = NSXPCConnection(machServiceName: LaunchRightsNames.helperMachService,
                                     options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
        connection.invalidationHandler = { log("XPC connection invalidated") }
        connection.interruptionHandler = { log("XPC connection interrupted") }
        connection.resume()
    }

    private var helper: HelperProtocol? {
        connection.remoteObjectProxyWithErrorHandler { error in
            log("XPC error: \(error.localizedDescription)")
        } as? HelperProtocol
    }

    func start() {
        reloadAllowlist()
        log("watching launches for \(allowlistedBundleIDs.count) allowlisted app(s)")

        // Confirm the daemon is reachable.
        helper?.ping { log("daemon says: \($0)") }

        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.didLaunchApplicationNotification,
                       object: nil,
                       queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.handleLaunch(app)
        }
        RunLoop.main.run()
    }

    private func reloadAllowlist() {
        let list = Allowlist.load()
        allowlistedBundleIDs = Set(list.apps.map { $0.bundleIdentifier })
    }

    private func handleLaunch(_ app: NSRunningApplication) {
        guard let bundleID = app.bundleIdentifier,
              allowlistedBundleIDs.contains(bundleID) else { return }
        guard let path = app.bundleURL?.path else { return }

        let pid = app.processIdentifier

        // Loop-breaker: if this instance is already running as root, it's the one
        // the daemon just launched. Leave it be.
        if uid(forPID: pid) == 0 {
            log("\(bundleID) already elevated (pid \(pid)) — ignoring")
            return
        }

        log("\(bundleID) launched by user (pid \(pid)); requesting elevation")
        app.forceTerminate()
        helper?.launchElevated(bundlePath: path) { ok, message in
            log("elevate \(bundleID): \(ok ? "OK" : "FAILED") — \(message)")
        }
    }
}

let agent = Agent()
agent.start()
