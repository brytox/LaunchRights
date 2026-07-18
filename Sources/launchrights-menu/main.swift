import AppKit
import LaunchRightsUI

/// launchrights-menu — the standalone status-bar control panel (no System Extension
/// management). The menu logic lives in `LaunchRightsUI.MenuController`, which the
/// System Extension host app reuses with extra activation controls.

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // menu-bar only, no Dock icon
let controller = MenuController()
app.delegate = controller
app.run()
