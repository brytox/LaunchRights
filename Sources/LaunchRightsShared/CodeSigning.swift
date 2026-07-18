import Foundation
import Security

/// Code-signing checks used by any privileged component to decide who it trusts.
public enum CodeSigning {

    /// Verify the process behind an XPC connection satisfies a requirement string.
    ///
    /// PROTOTYPE NOTE: identifies the peer by PID, which can be reused. The
    /// production version uses the connection's audit token
    /// (`kSecGuestAttributeAudit`) instead. (The ES daemon doesn't need this —
    /// it has no XPC surface.)
    public static func validatePeer(pid: pid_t, requirement: String) -> Bool {
        guard let req = makeRequirement(requirement) else { return false }
        let attributes = [kSecGuestAttributePid: NSNumber(value: pid)] as CFDictionary
        var code: SecCode?
        guard SecCodeCopyGuestWithAttributes(nil, attributes, [], &code) == errSecSuccess,
              let guestCode = code else {
            return false
        }
        return SecCodeCheckValidity(guestCode, [], req) == errSecSuccess
    }

    /// Verify the app on disk satisfies a requirement string. This is what stops
    /// a swapped/tampered binary from being elevated.
    public static func validateOnDisk(path: String, requirement: String) -> Bool {
        guard let req = makeRequirement(requirement) else { return false }
        let url = URL(fileURLWithPath: path) as CFURL
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url, [], &staticCode) == errSecSuccess,
              let code = staticCode else {
            return false
        }
        return SecStaticCodeCheckValidity(code, [], req) == errSecSuccess
    }

    private static func makeRequirement(_ string: String) -> SecRequirement? {
        var req: SecRequirement?
        guard SecRequirementCreateWithString(string as CFString, [], &req) == errSecSuccess else {
            return nil
        }
        return req
    }
}
