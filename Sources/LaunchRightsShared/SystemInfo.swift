import Foundation

/// Small process/identity lookups used across components.
public enum SystemInfo {

    /// Owning uid of a running process, or nil if it can't be determined.
    public static func uid(forPID pid: pid_t) -> uid_t? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        let rc = sysctl(&mib, 4, &info, &size, nil, 0)
        if rc != 0 || size == 0 { return nil }
        return info.kp_eproc.e_ucred.cr_uid
    }

    /// Short login name for a uid (e.g. "bob"), or nil.
    public static func username(forUID uid: uid_t) -> String? {
        guard let pw = getpwuid(uid) else { return nil }
        return String(cString: pw.pointee.pw_name)
    }
}
