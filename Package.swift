// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LaunchRights",
    platforms: [.macOS(.v13)],
    targets: [
        // Tiny C shim: fork + audit_session_join + exec, so a root daemon can
        // launch a GUI app into the requesting user's login session. Can't be
        // done from Swift/posix_spawn (needs code to run between fork and exec).
        .target(
            name: "CLaunchRightsSession"
        ),
        .target(
            name: "LaunchRightsShared",
            dependencies: ["CLaunchRightsSession"]
        ),
        // AppKit menu UI, kept out of LaunchRightsShared so the root daemons don't
        // link AppKit. Reused by the standalone menu app and the sysext host.
        .target(
            name: "LaunchRightsUI",
            dependencies: ["LaunchRightsShared"]
        ),
        // XPC / NSWorkspace prototype: root daemon + per-user launch observer.
        .executableTarget(
            name: "launchrightsd",
            dependencies: ["LaunchRightsShared"]
        ),
        .executableTarget(
            name: "launchrights-agent",
            dependencies: ["LaunchRightsShared"]
        ),
        // Status-bar control panel: shows the allowlist + recent elevations, and
        // is the future host for the ES System Extension.
        .executableTarget(
            name: "launchrights-menu",
            dependencies: ["LaunchRightsUI"]
        ),
        // Endpoint Security flavour: single root daemon, pre-exec interception.
        .executableTarget(
            name: "launchrightsd-es",
            dependencies: ["LaunchRightsShared"],
            linkerSettings: [
                .linkedLibrary("EndpointSecurity")
            ]
        ),
        // Headless test app: writes the identity it runs under to a log and
        // exits. Wrapped into IDProbe.app by scripts/build-test-app.sh to verify
        // `runAs` privilege drops without a GUI.
        .executableTarget(
            name: "idprobe"
        ),
    ]
)
