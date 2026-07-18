using System.Text.Json;
using System.Text.Json.Serialization;

namespace LaunchRights.Core;

/// <summary>One approved application. Parallel to the macOS AllowlistEntry.</summary>
public sealed class AllowlistEntry
{
    /// <summary>Logical, cross-platform id (matches the macOS entry id where shared).</summary>
    public string Id { get; set; } = "";

    public string? DisplayName { get; set; }

    /// <summary>Expected image path, e.g. C:\Program Files\NetConfig\NetConfig.exe. Matched case-insensitively.</summary>
    public string Path { get; set; } = "";

    /// <summary>
    /// Required Authenticode signer. This is the load-bearing control (the Windows
    /// equivalent of the macOS code-signing requirement). Provide at least one:
    ///   Thumbprint — SHA-256 (or SHA-1) cert thumbprint, hex, case-insensitive, no spaces (strongest).
    ///   Publisher  — substring that must appear in the signer's subject, e.g. "O=Contoso Ltd".
    /// Leave both null to SKIP verification — insecure, prototype only.
    /// </summary>
    public string? Thumbprint { get; set; }

    public string? Publisher { get; set; }
}

public sealed class Allowlist
{
    public List<AllowlistEntry> Apps { get; set; } = new();

    private static readonly JsonSerializerOptions Options = new()
    {
        PropertyNameCaseInsensitive = true,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
        WriteIndented = true,
    };

    public static Allowlist Load(string? path = null)
    {
        path ??= Paths.AllowlistPath;
        try
        {
            if (!File.Exists(path)) return new Allowlist();
            return JsonSerializer.Deserialize<Allowlist>(File.ReadAllText(path), Options) ?? new Allowlist();
        }
        catch
        {
            return new Allowlist();
        }
    }

    /// <summary>Find the entry whose Path matches the launched image (normalized, case-insensitive).</summary>
    public AllowlistEntry? Match(string imagePath)
    {
        var target = Normalize(imagePath);
        foreach (var e in Apps)
        {
            if (!string.IsNullOrWhiteSpace(e.Path) && Normalize(e.Path) == target)
                return e;
        }
        return null;
    }

    private static string Normalize(string p)
    {
        try { return System.IO.Path.GetFullPath(p).TrimEnd('\\').ToLowerInvariant(); }
        catch { return p.Trim().ToLowerInvariant(); }
    }
}
