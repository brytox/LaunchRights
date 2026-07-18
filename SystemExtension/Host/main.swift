import AppKit
import LaunchRightsUI

/// LaunchRights host app — the System Extension container.
///
/// Reuses the shared `MenuController` status-bar UI (allowlist / recent
/// elevations / manual launch) and injects System Extension activate/deactivate
/// controls via the `extraItems` hook. Launch it from /Applications to activate
/// the ES extension it embeds.

let manager = SystemExtensionManager()

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // menu-bar only
let controller = MenuController(extraItems: { manager.menuItems() })
app.delegate = controller
app.run()
