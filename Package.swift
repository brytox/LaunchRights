// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LaunchRights",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "LaunchRightsShared"
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
    ]
)
