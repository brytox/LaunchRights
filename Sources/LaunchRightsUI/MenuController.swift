import AppKit
import LaunchRightsShared

/// Shared status-bar controller used by both the standalone `launchrights-menu`
/// executable and the System Extension host app.
///
/// Lives in its own target (not `LaunchRightsShared`) so the root daemons never link
/// AppKit. Callers can inject extra menu items via `extraItems` — the host app
/// uses this to add System Extension activate/deactivate controls.
public final class MenuController: NSObject, NSApplicationDelegate, NSMenuDelegate {

    /// Returns extra items inserted just before the Quit entry. Called on every
    /// menu open, so it can reflect live state (e.g. sysext status).
    public typealias ExtraItemsProvider = () -> [NSMenuItem]

    private var statusItem: NSStatusItem!
    private let connection: NSXPCConnection
    private let extraItems: ExtraItemsProvider?
    private var cachedRecent: [String] = []
    private var cachedStatus = "connecting to daemon…"

    public init(extraItems: ExtraItemsProvider? = nil) {
        self.extraItems = extraItems
        connection = NSXPCConnection(machServiceName: LaunchRightsNames.helperMachService,
                                     options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
        connection.resume()
        super.init()
    }

    private var helper: HelperProtocol? {
        connection.remoteObjectProxyWithErrorHandler { error in
            NSLog("LaunchRightsUI: XPC error: \(error.localizedDescription)")
        } as? HelperProtocol
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "lock.shield", accessibilityDescription: "LaunchRights")
            button.image?.isTemplate = true
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        refreshStatus()
        refreshRecent()
    }

    public func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(disabledItem("LaunchRights"))
        menu.addItem(disabledItem("  " + cachedStatus))
        menu.addItem(.separator())

        menu.addItem(disabledItem("Approved apps"))
        let allowlist = Allowlist.load()
        if allowlist.apps.isEmpty {
            menu.addItem(disabledItem("  (allowlist empty)"))
        } else {
            for entry in allowlist.apps {
                let item = NSMenuItem(title: "  " + (entry.displayName ?? entry.bundleIdentifier),
                                      action: #selector(launchApp(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = entry.bundleIdentifier
                item.toolTip = "Launch elevated"
                menu.addItem(item)
            }
        }
        menu.addItem(.separator())

        menu.addItem(disabledItem("Recent elevations"))
        if cachedRecent.isEmpty {
            menu.addItem(disabledItem("  (none, or daemon unavailable)"))
        } else {
            for line in cachedRecent.reversed().prefix(10) {
                menu.addItem(disabledItem("  " + line))
            }
        }

        if let extraItems = extraItems?(), !extraItems.isEmpty {
            menu.addItem(.separator())
            extraItems.forEach { menu.addItem($0) }
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit LaunchRights",
                                action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        refreshStatus()
        refreshRecent()
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func refreshStatus() {
        let proxy = connection.remoteObjectProxyWithErrorHandler { [weak self] _ in
            DispatchQueue.main.async { self?.cachedStatus = "daemon not running" }
        } as? HelperProtocol
        proxy?.ping { [weak self] status in
            DispatchQueue.main.async { self?.cachedStatus = status }
        }
    }

    private func refreshRecent() {
        helper?.recentEvents(limit: 10) { [weak self] lines in
            DispatchQueue.main.async { self?.cachedRecent = lines }
        }
    }

    @objc private func launchApp(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            alert("App not found", "No installed application with identifier \(bundleID).")
            return
        }
        helper?.launchElevated(bundlePath: url.path) { [weak self] ok, message in
            DispatchQueue.main.async {
                self?.refreshRecent()
                if !ok { self?.alert("Elevation failed", message) }
            }
        }
    }

    public func alert(_ title: String, _ text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.runModal()
    }
}
