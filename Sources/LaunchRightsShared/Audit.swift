import Foundation

/// Who/what/why context for one elevation decision.
public struct ElevationContext {
    /// uid of the standard user whose action triggered the request.
    public let requestingUID: uid_t
    /// Which flavour asked: "es" or "xpc".
    public let source: String

    public init(requestingUID: uid_t, source: String) {
        self.requestingUID = requestingUID
        self.source = source
    }
}

/// One audited elevation decision. Written as a single JSON line.
public struct AuditRecord: Codable {
    public let timestamp: String       // ISO-8601
    public let source: String          // "es" | "xpc"
    public let requestingUID: UInt32
    public let requestingUser: String?
    public let outcome: String         // "launched" | "denied" | "failed"
    public let bundleID: String?
    public let displayName: String?
    public let bundlePath: String
    public let pid: Int32?
    public let message: String
}

/// Append-only, root-owned audit log.
///
/// The file is created 0600 (root read/write only) so standard users can neither
/// tamper with it nor read who-ran-what. Only privileged components write to it,
/// and it's read back to the UI via the daemon's XPC surface — never opened
/// directly by the unprivileged menu app.
public enum AuditLog {

    public static var path: String {
        ProcessInfo.processInfo.environment["LAUNCHRIGHTS_AUDIT"]
            ?? "/Library/Application Support/LaunchRights/audit.log"
    }

    private static let queue = DispatchQueue(label: "com.jigsaw24.launchrights.audit")

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    public static func now() -> String { isoFormatter.string(from: Date()) }

    public static func record(_ record: AuditRecord) {
        queue.sync {
            guard let data = try? JSONEncoder().encode(record),
                  var line = String(data: data, encoding: .utf8) else { return }
            line += "\n"
            let bytes = Data(line.utf8)
            if !FileManager.default.fileExists(atPath: path) {
                FileManager.default.createFile(atPath: path, contents: nil,
                                               attributes: [.posixPermissions: 0o600])
            }
            guard let handle = FileHandle(forWritingAtPath: path) else { return }
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            handle.write(bytes)
        }
    }

    /// Most-recent records (newest last), decoded from the tail of the log.
    public static func recentRecords(limit: Int) -> [AuditRecord] {
        guard let raw = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
        let lines = raw.split(separator: "\n").suffix(limit)
        let decoder = JSONDecoder()
        return lines.compactMap { try? decoder.decode(AuditRecord.self, from: Data($0.utf8)) }
    }

    /// Human-readable one-liners for display, e.g. "14:03  bob  LAUNCHED  Activity Monitor".
    public static func recent(limit: Int) -> [String] {
        let display = DateFormatter()
        display.dateFormat = "yyyy-MM-dd HH:mm"
        return recentRecords(limit: limit).map { r in
            let when = isoFormatter.date(from: r.timestamp).map { display.string(from: $0) } ?? r.timestamp
            let who = r.requestingUser ?? "uid \(r.requestingUID)"
            let what = r.displayName ?? r.bundleID ?? r.bundlePath
            return "\(when)  \(who)  \(r.outcome.uppercased())  \(what)"
        }
    }
}
