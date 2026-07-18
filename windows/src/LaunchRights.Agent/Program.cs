using System.Collections.Concurrent;
using System.Diagnostics;
using System.IO.Pipes;
using System.Management;
using LaunchRights.Core;

// LaunchRights.Agent — the auto-interception PROTOTYPE (the Windows analogue of the
// macOS NSWorkspace launch observer). It watches for process starts via WMI and, when
// a standard user launches an allowlisted app unelevated, kills that instance and asks
// the service to relaunch it elevated.
//
// This is "detect then relaunch", like the mac prototype — a brief flash. The production
// path is a kernel process-creation callback (PsSetCreateProcessNotifyRoutineEx) that
// vetoes/relaunches BEFORE the process runs — the analogue of the mac Endpoint Security
// extension, and, like it, needs a signed kernel driver.
//
// NOTE: receiving process-start events reliably usually needs the agent to run with
// admin rights (or as a service). WMI polling here is deliberately simple.

Console.WriteLine("LaunchRights agent: watching process starts…");

var allowlist = Allowlist.Load();
var allowed = allowlist.Apps
    .Where(a => !string.IsNullOrWhiteSpace(a.Path))
    .Select(a => System.IO.Path.GetFullPath(a.Path).ToLowerInvariant())
    .ToHashSet();

// Loop-breaker: don't re-intercept a path we just asked the service to relaunch.
var recentlyRelaunched = new ConcurrentDictionary<string, DateTime>();

var query = new WqlEventQuery(
    "__InstanceCreationEvent",
    TimeSpan.FromSeconds(1),
    "TargetInstance ISA 'Win32_Process'");

using var watcher = new ManagementEventWatcher(query);
watcher.EventArrived += (_, e) =>
{
    try
    {
        var proc = (ManagementBaseObject)e.NewEvent["TargetInstance"];
        var path = proc["ExecutablePath"] as string;
        if (string.IsNullOrEmpty(path)) return;
        var key = System.IO.Path.GetFullPath(path).ToLowerInvariant();
        if (!allowed.Contains(key)) return;

        // Skip if this is (probably) our own elevated relaunch.
        if (recentlyRelaunched.TryGetValue(key, out var when) && (DateTime.UtcNow - when) < TimeSpan.FromSeconds(15))
            return;

        var pid = Convert.ToInt32(proc["ProcessId"]);
        Console.WriteLine($"intercept: {path} (pid {pid}) — requesting elevation");

        recentlyRelaunched[key] = DateTime.UtcNow;
        try { Process.GetProcessById(pid).Kill(); } catch { /* may already be gone / not ours */ }

        _ = RequestElevationAsync(path);
    }
    catch (Exception ex) { Console.Error.WriteLine("event error: " + ex.Message); }
};

watcher.Start();
Console.WriteLine("Press Ctrl+C to stop.");
await Task.Delay(Timeout.Infinite);

static async Task RequestElevationAsync(string imagePath)
{
    try
    {
        using var client = new NamedPipeClientStream(".", Paths.PipeName, PipeDirection.InOut, PipeOptions.Asynchronous);
        await client.ConnectAsync(5000);
        await Ipc.WriteAsync(client, new PipeRequest { Command = "elevate", ImagePath = imagePath });
        var resp = await Ipc.ReadAsync<PipeResponse>(client);
        Console.WriteLine($"  service: {(resp?.Ok == true ? "OK" : "FAILED")} — {resp?.Message}");
    }
    catch (Exception ex) { Console.Error.WriteLine("  elevate request failed: " + ex.Message); }
}
