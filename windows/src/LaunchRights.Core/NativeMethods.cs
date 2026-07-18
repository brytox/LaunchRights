using System.Runtime.InteropServices;

namespace LaunchRights.Core;

/// <summary>Win32 interop for launching a process, elevated, in a user's session.</summary>
internal static class NativeMethods
{
    internal const uint TOKEN_DUPLICATE = 0x0002;
    internal const uint TOKEN_QUERY = 0x0008;
    internal const uint TOKEN_ASSIGN_PRIMARY = 0x0001;
    internal const uint TOKEN_ADJUST_DEFAULT = 0x0080;
    internal const uint TOKEN_ADJUST_SESSIONID = 0x0100;
    internal const uint MAXIMUM_ALLOWED = 0x02000000;

    internal const uint CREATE_UNICODE_ENVIRONMENT = 0x00000400;
    internal const uint CREATE_NEW_CONSOLE = 0x00000010;

    internal const int TokenSessionId = 12;    // TOKEN_INFORMATION_CLASS
    internal const int TokenLinkedToken = 19;  // TOKEN_INFORMATION_CLASS
    internal const int TokenElevation = 20;    // TOKEN_INFORMATION_CLASS (single DWORD)

    internal enum SECURITY_IMPERSONATION_LEVEL { Anonymous, Identification, Impersonation, Delegation }
    internal enum TOKEN_TYPE { TokenPrimary = 1, TokenImpersonation }

    [StructLayout(LayoutKind.Sequential)]
    internal struct SECURITY_ATTRIBUTES
    {
        public int nLength;
        public IntPtr lpSecurityDescriptor;
        public bool bInheritHandle;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    internal struct STARTUPINFO
    {
        public int cb;
        public string? lpReserved;
        public string? lpDesktop;
        public string? lpTitle;
        public int dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
        public short wShowWindow, cbReserved2;
        public IntPtr lpReserved2, hStdInput, hStdOutput, hStdError;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct PROCESS_INFORMATION
    {
        public IntPtr hProcess, hThread;
        public int dwProcessId, dwThreadId;
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    internal static extern IntPtr GetCurrentProcess();

    [DllImport("kernel32.dll", SetLastError = true)]
    internal static extern uint WTSGetActiveConsoleSessionId();

    [DllImport("kernel32.dll", SetLastError = true)]
    internal static extern bool CloseHandle(IntPtr hObject);

    [DllImport("advapi32.dll", SetLastError = true)]
    internal static extern bool OpenProcessToken(IntPtr ProcessHandle, uint DesiredAccess, out IntPtr TokenHandle);

    [DllImport("advapi32.dll", SetLastError = true)]
    internal static extern bool DuplicateTokenEx(
        IntPtr hExistingToken, uint dwDesiredAccess, ref SECURITY_ATTRIBUTES lpTokenAttributes,
        SECURITY_IMPERSONATION_LEVEL ImpersonationLevel, TOKEN_TYPE TokenType, out IntPtr phNewToken);

    [DllImport("advapi32.dll", SetLastError = true)]
    internal static extern bool SetTokenInformation(
        IntPtr TokenHandle, int TokenInformationClass, ref uint TokenInformation, int TokenInformationLength);

    [DllImport("advapi32.dll", SetLastError = true)]
    internal static extern bool GetTokenInformation(
        IntPtr TokenHandle, int TokenInformationClass, IntPtr TokenInformation,
        int TokenInformationLength, out int ReturnLength);

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    internal static extern bool CreateProcessAsUser(
        IntPtr hToken, string? lpApplicationName, string? lpCommandLine,
        ref SECURITY_ATTRIBUTES lpProcessAttributes, ref SECURITY_ATTRIBUTES lpThreadAttributes,
        bool bInheritHandles, uint dwCreationFlags, IntPtr lpEnvironment, string? lpCurrentDirectory,
        ref STARTUPINFO lpStartupInfo, out PROCESS_INFORMATION lpProcessInformation);

    [DllImport("userenv.dll", SetLastError = true)]
    internal static extern bool CreateEnvironmentBlock(out IntPtr lpEnvironment, IntPtr hToken, bool bInherit);

    [DllImport("userenv.dll", SetLastError = true)]
    internal static extern bool DestroyEnvironmentBlock(IntPtr lpEnvironment);

    [DllImport("wtsapi32.dll", SetLastError = true)]
    internal static extern bool WTSQueryUserToken(uint SessionId, out IntPtr phToken);
}
