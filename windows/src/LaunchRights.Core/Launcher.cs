using System.Runtime.InteropServices;
using static LaunchRights.Core.NativeMethods;

namespace LaunchRights.Core;

public enum LaunchStatus { Launched, Denied, Failed }

public sealed record LaunchOutcome(LaunchStatus Status, int Pid, string Message)
{
    public bool DidLaunch => Status == LaunchStatus.Launched;
}

/// <summary>
/// The elevation decision + launch — Windows counterpart of the macOS Launcher.
/// MUST run from the SYSTEM service.
///
/// Elevation identity, in preference order:
///   1. The interactive user's own token if it's already elevated (e.g. UAC off).
///   2. The user's LINKED elevated token (protected-admin users) — runs the app AS the
///      user, elevated, with their profile/HKCU. This is the correct, clean path.
///   3. Fallback: LocalSystem placed into the user's session — used only when the
///      interactive user is a true standard user with no admin token to grant. Making
///      a standard user's app run *as them* with admin needs temporary group membership
///      or an LSA/driver token minter (roadmap); we log which identity was used.
/// </summary>
public static class Launcher
{
    public static LaunchOutcome Elevate(string imagePath, Allowlist allowlist, string source,
        string? requestingUser, Action<string>? log = null)
    {
        LaunchOutcome Finish(LaunchStatus st, int pid, string msg, AllowlistEntry? e, string? sig)
        {
            AuditLog.Record(new AuditRecord
            {
                Timestamp = AuditLog.Now(),
                Source = source,
                RequestingUser = requestingUser,
                Outcome = st switch { LaunchStatus.Launched => "launched", LaunchStatus.Denied => "denied", _ => "failed" },
                Id = e?.Id,
                DisplayName = e?.DisplayName,
                ImagePath = imagePath,
                Signature = sig,
                Pid = pid > 0 ? pid : null,
                Message = msg,
            });
            return new LaunchOutcome(st, pid, msg);
        }

        if (!File.Exists(imagePath))
            return Finish(LaunchStatus.Failed, 0, $"not found: {imagePath}", null, null);

        var entry = allowlist.Match(imagePath);
        if (entry is null)
            return Finish(LaunchStatus.Denied, 0, $"not allowlisted: {imagePath}", null, null);

        var sig = Authenticode.Verify(imagePath);
        if (!Authenticode.Satisfies(sig, entry, out var reason))
            return Finish(LaunchStatus.Denied, 0, $"signature check failed: {reason}", entry, sig.Thumbprint);

        if (string.IsNullOrEmpty(entry.Thumbprint) && string.IsNullOrEmpty(entry.Publisher))
            log?.Invoke($"WARNING: elevating {entry.Id} with no signature requirement (insecure)");

        try
        {
            int pid = SpawnElevated(imagePath, out string identity);
            return Finish(LaunchStatus.Launched, pid,
                $"launched {entry.DisplayName ?? entry.Id} elevated as {identity} (pid {pid})",
                entry, sig.Thumbprint ?? sig.Subject);
        }
        catch (Exception ex)
        {
            return Finish(LaunchStatus.Failed, 0, $"spawn failed: {ex.Message}", entry, sig.Thumbprint);
        }
    }

    private static int SpawnElevated(string imagePath, out string identity)
    {
        uint session = WTSGetActiveConsoleSessionId();
        if (session == 0xFFFFFFFF) throw new InvalidOperationException("no active console session");

        IntPtr launchToken = TryGetElevatedUserToken(session, out identity);
        if (launchToken == IntPtr.Zero)
        {
            launchToken = DuplicateSystemTokenIntoSession(session);
            identity = "SYSTEM (fallback — interactive user is not an administrator)";
        }

        IntPtr env = IntPtr.Zero;
        try
        {
            CreateEnvironmentBlock(out env, launchToken, false); // best-effort user environment

            var sa = new SECURITY_ATTRIBUTES { nLength = Marshal.SizeOf<SECURITY_ATTRIBUTES>() };
            var si = new STARTUPINFO
            {
                cb = Marshal.SizeOf<STARTUPINFO>(),
                lpDesktop = @"winsta0\default",
            };
            string cmdline = "\"" + imagePath + "\"";
            string? workingDir = Path.GetDirectoryName(imagePath);

            if (!CreateProcessAsUser(launchToken, null, cmdline, ref sa, ref sa, false,
                    CREATE_UNICODE_ENVIRONMENT | CREATE_NEW_CONSOLE, env, workingDir, ref si, out var pi))
                throw new InvalidOperationException($"CreateProcessAsUser failed ({LastError()})");

            CloseHandle(pi.hThread);
            CloseHandle(pi.hProcess);
            return pi.dwProcessId;
        }
        finally
        {
            if (env != IntPtr.Zero) DestroyEnvironmentBlock(env);
            if (launchToken != IntPtr.Zero) CloseHandle(launchToken);
        }
    }

    /// <summary>Returns a primary, elevated token for the interactive user, or IntPtr.Zero
    /// if the user has no admin token (true standard user). Sets <paramref name="identity"/>.</summary>
    private static IntPtr TryGetElevatedUserToken(uint session, out string identity)
    {
        identity = "";
        if (!WTSQueryUserToken(session, out IntPtr hUser)) return IntPtr.Zero;

        try
        {
            if (IsTokenElevated(hUser))
            {
                identity = "the signed-in user (already elevated)";
                return DuplicatePrimary(hUser);
            }

            if (TryGetLinkedToken(hUser, out IntPtr hLinked))
            {
                try
                {
                    if (IsTokenElevated(hLinked))
                    {
                        identity = "the signed-in user (elevated)";
                        return DuplicatePrimary(hLinked);
                    }
                }
                finally { CloseHandle(hLinked); }
            }

            return IntPtr.Zero; // standard user — caller falls back to SYSTEM
        }
        finally { CloseHandle(hUser); }
    }

    private static IntPtr DuplicatePrimary(IntPtr token)
    {
        var sa = new SECURITY_ATTRIBUTES { nLength = Marshal.SizeOf<SECURITY_ATTRIBUTES>() };
        if (!DuplicateTokenEx(token, MAXIMUM_ALLOWED, ref sa,
                SECURITY_IMPERSONATION_LEVEL.Impersonation, TOKEN_TYPE.TokenPrimary, out IntPtr dup))
            throw new InvalidOperationException($"DuplicateTokenEx failed ({LastError()})");
        return dup;
    }

    private static IntPtr DuplicateSystemTokenIntoSession(uint session)
    {
        if (!OpenProcessToken(GetCurrentProcess(),
                TOKEN_DUPLICATE | TOKEN_QUERY | TOKEN_ASSIGN_PRIMARY | TOKEN_ADJUST_DEFAULT | TOKEN_ADJUST_SESSIONID,
                out IntPtr hToken))
            throw new InvalidOperationException($"OpenProcessToken failed ({LastError()})");
        try
        {
            IntPtr dup = DuplicatePrimary(hToken);
            if (!SetTokenInformation(dup, TokenSessionId, ref session, sizeof(uint)))
            {
                CloseHandle(dup);
                throw new InvalidOperationException($"SetTokenInformation(session) failed ({LastError()})");
            }
            return dup;
        }
        finally { CloseHandle(hToken); }
    }

    private static bool IsTokenElevated(IntPtr token)
    {
        IntPtr buf = Marshal.AllocHGlobal(sizeof(int)); // TOKEN_ELEVATION = single DWORD
        try
        {
            return GetTokenInformation(token, TokenElevation, buf, sizeof(int), out _)
                   && Marshal.ReadInt32(buf) != 0;
        }
        finally { Marshal.FreeHGlobal(buf); }
    }

    private static bool TryGetLinkedToken(IntPtr token, out IntPtr linked)
    {
        linked = IntPtr.Zero;
        IntPtr buf = Marshal.AllocHGlobal(IntPtr.Size); // TOKEN_LINKED_TOKEN = single HANDLE
        try
        {
            if (GetTokenInformation(token, TokenLinkedToken, buf, IntPtr.Size, out _))
            {
                linked = Marshal.ReadIntPtr(buf);
                return linked != IntPtr.Zero;
            }
            return false;
        }
        finally { Marshal.FreeHGlobal(buf); }
    }

    private static string LastError() => $"win32 {Marshal.GetLastWin32Error()}";
}
