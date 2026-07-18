using System.IO.Pipes;
using LaunchRights.Core;

// LaunchRights.Run — the user-facing trigger. A standard user runs:
//   LaunchRights.Run "C:\Program Files\NetConfig\NetConfig.exe"
//   LaunchRights.Run com.corp.NetConfig          (an allowlist id)
// It asks the service to launch the approved app elevated. Wire this to a
// right-click "Run with LaunchRights" verb or a Start-menu shortcut per app.

if (args.Length < 1)
{
    Console.Error.WriteLine("usage: LaunchRights.Run <image-path | allowlist-id>");
    return 2;
}

string arg = args[0];
string imagePath = arg;

// If it isn't a real path, treat it as an allowlist id and resolve to a path.
if (!File.Exists(imagePath))
{
    var entry = Allowlist.Load().Apps
        .FirstOrDefault(a => string.Equals(a.Id, arg, StringComparison.OrdinalIgnoreCase));
    if (entry is not null && !string.IsNullOrEmpty(entry.Path))
        imagePath = entry.Path;
}

try
{
    using var client = new NamedPipeClientStream(".", Paths.PipeName, PipeDirection.InOut, PipeOptions.Asynchronous);
    await client.ConnectAsync(5000);
    await Ipc.WriteAsync(client, new PipeRequest { Command = "elevate", ImagePath = imagePath });
    var resp = await Ipc.ReadAsync<PipeResponse>(client);

    if (resp is null) { Console.Error.WriteLine("no response from service"); return 1; }
    Console.WriteLine((resp.Ok ? "OK: " : "FAILED: ") + resp.Message);
    return resp.Ok ? 0 : 1;
}
catch (TimeoutException)
{
    Console.Error.WriteLine("could not reach the LaunchRights service (is it running?)");
    return 1;
}
