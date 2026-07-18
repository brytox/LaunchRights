import Foundation

/// XPC contract between the per-user agent (client) and the root daemon (server).
///
/// The agent NEVER runs anything itself — it only asks the daemon to elevate an
/// app that the daemon independently re-validates. All trust decisions live in
/// the daemon, which runs as root.
@objc public protocol HelperProtocol {

    /// Ask the daemon to (re)launch an allowlisted app with elevated (root) rights.
    ///
    /// - Parameters:
    ///   - bundlePath: absolute path to the `.app` the agent observed launching.
    ///     This is treated as UNTRUSTED input: the daemon reads the bundle id,
    ///     matches it against the allowlist, and re-verifies the on-disk code
    ///     signature before launching anything.
    ///   - reply: `(success, message)` — message is human-readable for logs/UI.
    func launchElevated(bundlePath: String, withReply reply: @escaping (Bool, String) -> Void)

    /// Liveness / version probe. Returns a short status string.
    func ping(withReply reply: @escaping (String) -> Void)

    /// Most-recent elevation events, formatted for display. Served by the root
    /// daemon so the unprivileged UI never has to read the root-only audit log
    /// directly.
    func recentEvents(limit: Int, withReply reply: @escaping ([String]) -> Void)
}

public enum LaunchRightsNames {
    /// Mach service the daemon registers (must match the LaunchDaemon plist).
    public static let helperMachService = "com.jigsaw24.launchrights.helper"

    /// Root-owned allowlist location.
    public static let allowlistPath = "/Library/Application Support/LaunchRights/allowlist.json"
}

/// One approved application.
public struct AllowlistEntry: Codable {
    /// CFBundleIdentifier the app must report (e.g. "com.jigsaw24.SomeAdminTool").
    public let bundleIdentifier: String

    /// Code Signing Requirement the on-disk app MUST satisfy before we elevate it.
    /// This is the load-bearing security control — it stops an attacker swapping
    /// the binary for something else with the same bundle id.
    ///
    /// Examples:
    ///   Team-ID pinned (recommended for production):
    ///     anchor apple generic and certificate leaf[subject.OU] = "ABCDE12345"
    ///   Apple-signed system tool:
    ///     anchor apple
    ///   Ad-hoc prototype (WEAK — identity only, no anchor):
    ///     identifier "com.jigsaw24.SomeAdminTool"
    ///
    /// An empty string SKIPS verification entirely. That is INSECURE and only
    /// intended for the earliest local prototyping — never ship it empty.
    public let requirement: String

    /// Optional friendly name for logs / future UI.
    public let displayName: String?

    public init(bundleIdentifier: String, requirement: String, displayName: String? = nil) {
        self.bundleIdentifier = bundleIdentifier
        self.requirement = requirement
        self.displayName = displayName
    }
}

public struct Allowlist: Codable {
    public let apps: [AllowlistEntry]

    public init(apps: [AllowlistEntry]) {
        self.apps = apps
    }

    /// Load and decode the allowlist from disk. Returns an empty list on any error.
    public static func load(from path: String = LaunchRightsNames.allowlistPath) -> Allowlist {
        guard let data = FileManager.default.contents(atPath: path) else {
            return Allowlist(apps: [])
        }
        return (try? JSONDecoder().decode(Allowlist.self, from: data)) ?? Allowlist(apps: [])
    }

    public func entry(forBundleIdentifier bundleID: String) -> AllowlistEntry? {
        apps.first { $0.bundleIdentifier == bundleID }
    }
}
