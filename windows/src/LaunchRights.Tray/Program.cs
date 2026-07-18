using System.IO.Pipes;
using LaunchRights.Core;

namespace LaunchRights.Tray;

// LaunchRights.Tray — the status-bar control panel (Windows counterpart of the mac
// launchrights-menu). Runs per-user in the notification area. Shows service status,
// the approved-apps list, and recent elevations (fetched from the service over the
// pipe, since the audit log is SYSTEM-only), and offers a manual "run elevated".

static class Program
{
    [STAThread]
    static void Main()
    {
        ApplicationConfiguration.Initialize();
        Application.Run(new TrayApp());
    }
}

sealed class TrayApp : ApplicationContext
{
    private readonly NotifyIcon _icon;
    private readonly ContextMenuStrip _menu = new();
    private string _status = "connecting to service…";
    private string[] _recent = Array.Empty<string>();

    public TrayApp()
    {
        _menu.Opening += (_, _) => RebuildMenu();
        _icon = new NotifyIcon
        {
            Text = "LaunchRights",
            Icon = System.Drawing.SystemIcons.Shield,
            Visible = true,
            ContextMenuStrip = _menu,
        };
        _ = RefreshAsync();
    }

    private void RebuildMenu()
    {
        _menu.Items.Clear();
        AddLabel("LaunchRights");
        AddLabel("  " + _status);
        _menu.Items.Add(new ToolStripSeparator());

        AddLabel("Approved apps");
        var apps = Allowlist.Load().Apps;
        if (apps.Count == 0)
        {
            AddLabel("  (allowlist empty)");
        }
        else
        {
            foreach (var a in apps)
            {
                var item = new ToolStripMenuItem("  " + (a.DisplayName ?? a.Id)) { ToolTipText = "Run elevated" };
                var entry = a;
                item.Click += async (_, _) => await ElevateAsync(entry);
                _menu.Items.Add(item);
            }
        }

        _menu.Items.Add(new ToolStripSeparator());
        AddLabel("Recent elevations");
        if (_recent.Length == 0)
            AddLabel("  (none, or service unavailable)");
        else
            foreach (var line in _recent.Reverse().Take(10))
                AddLabel("  " + line);

        _menu.Items.Add(new ToolStripSeparator());
        var quit = new ToolStripMenuItem("Quit LaunchRights");
        quit.Click += (_, _) => { _icon.Visible = false; ExitThread(); };
        _menu.Items.Add(quit);

        _ = RefreshAsync(); // update caches for the next open
    }

    private void AddLabel(string text) =>
        _menu.Items.Add(new ToolStripMenuItem(text) { Enabled = false });

    private async Task RefreshAsync()
    {
        try
        {
            var ping = await SendAsync(new PipeRequest { Command = "ping" });
            _status = ping?.Ok == true ? ping.Message : "service not running";
        }
        catch { _status = "service not running"; }

        try
        {
            var recent = await SendAsync(new PipeRequest { Command = "recent", Limit = 10 });
            _recent = recent?.Lines ?? Array.Empty<string>();
        }
        catch { _recent = Array.Empty<string>(); }
    }

    private async Task ElevateAsync(AllowlistEntry entry)
    {
        try
        {
            var resp = await SendAsync(new PipeRequest { Command = "elevate", ImagePath = entry.Path });
            var ok = resp?.Ok == true;
            _icon.ShowBalloonTip(ok ? 3000 : 4000, "LaunchRights",
                resp?.Message ?? "no response from service", ok ? ToolTipIcon.Info : ToolTipIcon.Error);
        }
        catch (Exception ex)
        {
            _icon.ShowBalloonTip(4000, "LaunchRights", ex.Message, ToolTipIcon.Error);
        }
        await RefreshAsync();
    }

    private static async Task<PipeResponse?> SendAsync(PipeRequest req)
    {
        using var client = new NamedPipeClientStream(".", Paths.PipeName, PipeDirection.InOut, PipeOptions.Asynchronous);
        await client.ConnectAsync(3000);
        await Ipc.WriteAsync(client, req);
        return await Ipc.ReadAsync<PipeResponse>(client);
    }
}
