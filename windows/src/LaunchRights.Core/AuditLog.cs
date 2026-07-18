using System.Text.Json;

namespace LaunchRights.Core;

/// <summary>One audited elevation decision — same shape as the macOS AuditRecord
/// so a central console can read both fleets' logs identically.</summary>
public sealed class AuditRecord
{
    public string Timestamp { get; set; } = "";
    public string Source { get; set; } = "";        // "win-service" | "win-agent"
    public string? RequestingUser { get; set; }
    public string Outcome { get; set; } = "";        // "launched" | "denied" | "failed"
    public string? Id { get; set; }
    public string? DisplayName { get; set; }
    public string ImagePath { get; set; } = "";
    public string? Signature { get; set; }           // thumbprint / subject that matched
    public int? Pid { get; set; }
    public string Message { get; set; } = "";
}

/// <summary>Append-only audit trail. Lives in %ProgramData%\LaunchRights\audit.log,
/// ACL'd so standard users cannot read or tamper (set by the installer).</summary>
public static class AuditLog
{
    private static readonly object Gate = new();
    private static readonly JsonSerializerOptions Options = new() { WriteIndented = false };

    public static string Now() => DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ");

    public static void Record(AuditRecord record)
    {
        try
        {
            Directory.CreateDirectory(Paths.BaseDir);
            var line = JsonSerializer.Serialize(record, Options) + Environment.NewLine;
            lock (Gate) { File.AppendAllText(Paths.AuditPath, line); }
        }
        catch { /* never let auditing crash the caller; surfaced via service log instead */ }
    }

    public static IReadOnlyList<string> Recent(int limit)
    {
        try
        {
            if (!File.Exists(Paths.AuditPath)) return Array.Empty<string>();
            var lines = File.ReadLines(Paths.AuditPath).TakeLast(Math.Clamp(limit, 1, 200));
            var outp = new List<string>();
            foreach (var l in lines)
            {
                var r = JsonSerializer.Deserialize<AuditRecord>(l);
                if (r is null) continue;
                var who = r.RequestingUser ?? "?";
                var what = r.DisplayName ?? r.Id ?? r.ImagePath;
                outp.Add($"{r.Timestamp}  {who}  {r.Outcome.ToUpperInvariant()}  {what}");
            }
            return outp;
        }
        catch { return Array.Empty<string>(); }
    }
}
