import Foundation
import AppKit
import SystemExtensions

/// Drives activation/deactivation of the Endpoint Security system extension from
/// the host app. Only apps in /Applications can activate extensions, and the user
/// (or MDM policy) must approve them.
final class SystemExtensionManager: NSObject, OSSystemExtensionRequestDelegate {

    /// Must match the extension target's bundle id and be prefixed by the host
    /// app's bundle id (com.jigsaw24.launchrights -> com.jigsaw24.launchrights.es).
    private let extensionIdentifier = "com.jigsaw24.launchrights.es"

    private(set) var status = "not activated"

    // MARK: Actions

    @objc func activate() {
        status = "activating…"
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: extensionIdentifier, queue: .main)
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }

    @objc func deactivate() {
        status = "deactivating…"
        let request = OSSystemExtensionRequest.deactivationRequest(
            forExtensionWithIdentifier: extensionIdentifier, queue: .main)
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }

    /// Extra menu items injected into the shared status menu.
    func menuItems() -> [NSMenuItem] {
        let statusItem = NSMenuItem(title: "Extension: \(status)", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false

        let activate = NSMenuItem(title: "Activate / Update Extension",
                                  action: #selector(activate), keyEquivalent: "")
        activate.target = self

        let deactivate = NSMenuItem(title: "Deactivate Extension",
                                    action: #selector(deactivate), keyEquivalent: "")
        deactivate.target = self

        return [statusItem, activate, deactivate]
    }

    // MARK: OSSystemExtensionRequestDelegate

    func request(_ request: OSSystemExtensionRequest,
                 actionForReplacingExtension existing: OSSystemExtensionProperties,
                 withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        NSLog("LaunchRights host: replacing extension %@ -> %@", existing.bundleVersion, ext.bundleVersion)
        return .replace
    }

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        status = "awaiting approval — System Settings ▸ Privacy & Security"
        NSLog("LaunchRights host: %@", status)
    }

    func request(_ request: OSSystemExtensionRequest,
                 didFinishWithResult result: OSSystemExtensionRequest.Result) {
        switch result {
        case .completed:                status = "active"
        case .willCompleteAfterReboot:  status = "active after reboot"
        @unknown default:               status = "finished (code \(result.rawValue))"
        }
        NSLog("LaunchRights host: request finished: %@", status)
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        status = "failed: \(error.localizedDescription)"
        NSLog("LaunchRights host: request failed: %@", error.localizedDescription)
    }
}
