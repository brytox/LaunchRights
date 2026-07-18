namespace LaunchRights.Core;

/// <summary>
/// Well-known locations. The base dir is machine-wide %ProgramData%\LaunchRights —
/// the Windows analogue of macOS /Library/Application Support/LaunchRights. Lock it
/// down with an ACL so standard users can read but not write (see install script).
/// </summary>
public static class Paths
{
    public static string BaseDir =>
        Environment.GetEnvironmentVariable("LAUNCHRIGHTS_DIR")
        ?? System.IO.Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
            "LaunchRights");

    public static string AllowlistPath => System.IO.Path.Combine(BaseDir, "allowlist.json");

    public static string AuditPath => System.IO.Path.Combine(BaseDir, "audit.log");

    /// <summary>Named pipe the service listens on (analogue of the mac Mach service).</summary>
    public const string PipeName = "LaunchRights";
}
