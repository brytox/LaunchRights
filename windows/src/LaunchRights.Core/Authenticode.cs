using System.Runtime.InteropServices;
using System.Security.Cryptography.X509Certificates;

namespace LaunchRights.Core;

public sealed class SignatureInfo
{
    public bool Trusted { get; init; }
    public string? Thumbprint { get; init; }   // SHA-1 thumbprint (X509Certificate2.Thumbprint)
    public string? Subject { get; init; }
    public string Detail { get; init; } = "";
}

/// <summary>
/// Authenticode verification — the Windows analogue of the macOS on-disk code-signature
/// check. Confirms the file has a trusted signature chain (WinVerifyTrust) and extracts
/// the signer certificate so the service can pin it against the allowlist.
/// </summary>
public static class Authenticode
{
    public static SignatureInfo Verify(string filePath)
    {
        bool trusted = WinVerifyTrustFile(filePath, out string detail);
        string? thumb = null, subject = null;
        try
        {
            using var cert = new X509Certificate2(X509Certificate.CreateFromSignedFile(filePath));
            thumb = cert.Thumbprint;
            subject = cert.Subject;
        }
        catch (Exception ex)
        {
            detail = string.IsNullOrEmpty(detail) ? ex.Message : $"{detail}; signer read failed: {ex.Message}";
        }
        return new SignatureInfo { Trusted = trusted, Thumbprint = thumb, Subject = subject, Detail = detail };
    }

    /// <summary>True if <paramref name="sig"/> satisfies the allowlist entry's pin.</summary>
    public static bool Satisfies(SignatureInfo sig, AllowlistEntry entry, out string reason)
    {
        if (string.IsNullOrEmpty(entry.Thumbprint) && string.IsNullOrEmpty(entry.Publisher))
        {
            reason = "no signature requirement set (insecure)";
            return true; // prototype-only path
        }
        if (!sig.Trusted)
        {
            reason = $"untrusted signature ({sig.Detail})";
            return false;
        }
        if (!string.IsNullOrEmpty(entry.Thumbprint))
        {
            var want = entry.Thumbprint.Replace(" ", "").Trim();
            if (!string.Equals(want, sig.Thumbprint, StringComparison.OrdinalIgnoreCase))
            {
                reason = "thumbprint mismatch";
                return false;
            }
        }
        if (!string.IsNullOrEmpty(entry.Publisher))
        {
            if (sig.Subject is null || !sig.Subject.Contains(entry.Publisher, StringComparison.OrdinalIgnoreCase))
            {
                reason = "publisher mismatch";
                return false;
            }
        }
        reason = "ok";
        return true;
    }

    // ---- WinVerifyTrust P/Invoke ----

    private static bool WinVerifyTrustFile(string path, out string detail)
    {
        var actionId = new Guid("00AAC56B-CD44-11d0-8CC2-00C04FC295EE"); // WINTRUST_ACTION_GENERIC_VERIFY_V2
        var fileInfo = new WINTRUST_FILE_INFO
        {
            cbStruct = (uint)Marshal.SizeOf<WINTRUST_FILE_INFO>(),
            pcwszFilePath = path,
            hFile = IntPtr.Zero,
            pgKnownSubject = IntPtr.Zero,
        };
        IntPtr pFile = Marshal.AllocHGlobal(Marshal.SizeOf<WINTRUST_FILE_INFO>());
        try
        {
            Marshal.StructureToPtr(fileInfo, pFile, false);
            var data = new WINTRUST_DATA
            {
                cbStruct = (uint)Marshal.SizeOf<WINTRUST_DATA>(),
                dwUIChoice = WTD_UI_NONE,
                fdwRevocationChecks = WTD_REVOKE_NONE,
                dwUnionChoice = WTD_CHOICE_FILE,
                pFile = pFile,
                dwStateAction = WTD_STATEACTION_VERIFY,
                dwProvFlags = WTD_SAFER_FLAG,
            };
            int rc = WinVerifyTrust(IntPtr.Zero, ref actionId, ref data);

            // Always close the state.
            data.dwStateAction = WTD_STATEACTION_CLOSE;
            WinVerifyTrust(IntPtr.Zero, ref actionId, ref data);

            detail = rc == 0 ? "trusted" : $"WinVerifyTrust=0x{rc:X8}";
            return rc == 0;
        }
        finally
        {
            Marshal.FreeHGlobal(pFile);
        }
    }

    private const uint WTD_UI_NONE = 2;
    private const uint WTD_REVOKE_NONE = 0;
    private const uint WTD_CHOICE_FILE = 1;
    private const uint WTD_STATEACTION_VERIFY = 1;
    private const uint WTD_STATEACTION_CLOSE = 2;
    private const uint WTD_SAFER_FLAG = 0x100;

    [StructLayout(LayoutKind.Sequential)]
    private struct WINTRUST_FILE_INFO
    {
        public uint cbStruct;
        [MarshalAs(UnmanagedType.LPWStr)] public string pcwszFilePath;
        public IntPtr hFile;
        public IntPtr pgKnownSubject;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct WINTRUST_DATA
    {
        public uint cbStruct;
        public IntPtr pPolicyCallbackData;
        public IntPtr pSIPClientData;
        public uint dwUIChoice;
        public uint fdwRevocationChecks;
        public uint dwUnionChoice;
        public IntPtr pFile;
        public uint dwStateAction;
        public IntPtr hWVTStateData;
        public IntPtr pwszURLReference;
        public uint dwProvFlags;
        public uint dwUIContext;
        public IntPtr pSignatureSettings;
    }

    [DllImport("wintrust.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern int WinVerifyTrust(IntPtr hwnd, ref Guid pgActionID, ref WINTRUST_DATA pWVTData);
}
