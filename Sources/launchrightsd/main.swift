import Foundation
import LaunchRightsShared

/// launchrightsd — the privileged helper (XPC / NSWorkspace prototype flavour).
///
/// Runs as root via a LaunchDaemon. The XPC surface (ping / recentEvents /
/// launchElevated) lives in the shared `HelperService`; the per-user
/// `launchrights-agent` observes launches and drives `launchElevated`.
///
/// For pre-exec interception without an agent, see the `launchrightsd-es` target.

let service = HelperService(daemonName: "launchrightsd (xpc)",
                            log: { NSLog("launchrightsd: \($0)") })
service.resume()
NSLog("launchrightsd: started")
RunLoop.main.run()
