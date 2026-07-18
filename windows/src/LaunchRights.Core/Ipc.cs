using System.Text;
using System.Text.Json;

namespace LaunchRights.Core;

/// <summary>One request over the pipe. Command is "elevate" | "recent" | "ping"
/// (mirrors the macOS HelperProtocol: launchElevated / recentEvents / ping).</summary>
public sealed class PipeRequest
{
    public string Command { get; set; } = "elevate";
    public string? ImagePath { get; set; }   // for "elevate"
    public int Limit { get; set; } = 10;      // for "recent"
}

public sealed class PipeResponse
{
    public bool Ok { get; set; }
    public string Message { get; set; } = "";
    public string[]? Lines { get; set; }      // for "recent"
}

/// <summary>Newline-delimited JSON over a pipe stream — one request, one response.</summary>
public static class Ipc
{
    private static readonly JsonSerializerOptions Options = new() { PropertyNameCaseInsensitive = true };

    public static async Task WriteAsync<T>(Stream s, T value, CancellationToken ct = default)
    {
        var bytes = Encoding.UTF8.GetBytes(JsonSerializer.Serialize(value, Options) + "\n");
        await s.WriteAsync(bytes, ct);
        await s.FlushAsync(ct);
    }

    public static async Task<T?> ReadAsync<T>(Stream s, CancellationToken ct = default)
    {
        var buf = new byte[8192];
        var sb = new StringBuilder();
        while (true)
        {
            int n = await s.ReadAsync(buf, ct);
            if (n <= 0) break;
            sb.Append(Encoding.UTF8.GetString(buf, 0, n));
            if (sb.ToString().Contains('\n')) break;
        }
        var line = sb.ToString().Split('\n', 2)[0].Trim();
        return string.IsNullOrEmpty(line) ? default : JsonSerializer.Deserialize<T>(line, Options);
    }
}
