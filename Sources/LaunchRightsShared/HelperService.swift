import Foundation

/// The XPC surface both daemons expose (`com.jigsaw24.launchrights.helper`):
/// liveness, recent audit events, and a manual elevation entry point.
///
/// Sharing this means the menu app talks to whichever flavour is installed —
/// the XPC prototype (`launchrightsd`) or the Endpoint Security daemon
/// (`launchrightsd-es`) — with no client-side changes. Only one flavour registers
/// the Mach service at a time (don't run both).
public final class HelperService: NSObject, HelperProtocol, NSXPCListenerDelegate {

    private let daemonName: String
    private let peerRequirement: String
    private let listener: NSXPCListener
    private let log: (String) -> Void

    /// - Parameters:
    ///   - daemonName: identity reported by `ping` (e.g. "launchrightsd-es").
    ///   - peerRequirement: signing requirement the connecting UI must satisfy.
    ///     Defaults to `LAUNCHRIGHTS_AGENT_REQ`; empty skips the check (prototype only).
    public init(daemonName: String,
                peerRequirement: String = ProcessInfo.processInfo.environment["LAUNCHRIGHTS_AGENT_REQ"] ?? "",
                log: @escaping (String) -> Void = { _ in }) {
        self.daemonName = daemonName
        self.peerRequirement = peerRequirement
        self.listener = NSXPCListener(machServiceName: LaunchRightsNames.helperMachService)
        self.log = log
        super.init()
        listener.delegate = self
    }

    /// Start listening. Under launchd (MachServices declared in the plist) this
    /// receives connections; run bare in the foreground it simply gets none.
    public func resume() {
        listener.resume()
        log("XPC surface up on \(LaunchRightsNames.helperMachService)")
    }

    // MARK: NSXPCListenerDelegate

    public func listener(_ listener: NSXPCListener,
                         shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        let pid = newConnection.processIdentifier
        if peerRequirement.isEmpty {
            log("WARNING: accepting pid \(pid) WITHOUT peer verification (LAUNCHRIGHTS_AGENT_REQ unset)")
        } else if !CodeSigning.validatePeer(pid: pid, requirement: peerRequirement) {
            log("rejected connection from pid \(pid): failed requirement")
            return false
        }
        newConnection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }

    // MARK: HelperProtocol

    public func ping(withReply reply: @escaping (String) -> Void) {
        reply("\(daemonName) alive, uid=\(getuid())")
    }

    public func recentEvents(limit: Int, withReply reply: @escaping ([String]) -> Void) {
        reply(AuditLog.recent(limit: max(1, min(limit, 100))))
    }

    public func launchElevated(bundlePath: String, withReply reply: @escaping (Bool, String) -> Void) {
        // Attribute to the user running the calling UI. Requests arriving via XPC
        // are tagged "xpc" regardless of which daemon serves them (ES interceptions
        // are tagged "es" on their own path).
        let callerPID = NSXPCConnection.current()?.processIdentifier ?? -1
        let requestingUID = SystemInfo.uid(forPID: callerPID) ?? getuid()
        let outcome = Launcher.elevate(bundlePath: bundlePath,
                                       allowlist: Allowlist.load(),
                                       context: ElevationContext(requestingUID: requestingUID, source: "xpc"),
                                       log: log)
        log(outcome.message)
        reply(outcome.didLaunch, outcome.message)
    }
}
