using System.IO.Pipes;
using System.Security.AccessControl;
using System.Security.Principal;
using LaunchRights.Core;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace LaunchRights.Service;

/// <summary>
/// Named-pipe server (the XPC analogue). One connection at a time: read a
/// PipeRequest (ping / recent / elevate), re-validate it independently, respond.
/// All trust decisions live here — the caller is never believed.
/// </summary>
public sealed class ElevationPipeServer : BackgroundService
{
    private readonly ILogger<ElevationPipeServer> _log;

    public ElevationPipeServer(ILogger<ElevationPipeServer> log) => _log = log;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _log.LogInformation("LaunchRights service started; listening on pipe \\\\.\\pipe\\{Pipe}", Paths.PipeName);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var server = CreateSecuredPipe();
                await server.WaitForConnectionAsync(stoppingToken);
                await HandleConnectionAsync(server, stoppingToken);
            }
            catch (OperationCanceledException) { break; }
            catch (Exception ex)
            {
                _log.LogError(ex, "pipe loop error");
                await Task.Delay(500, stoppingToken);
            }
        }
    }

    private static NamedPipeServerStream CreateSecuredPipe()
    {
        var security = new PipeSecurity();
        // Any authenticated user may connect; the service still re-validates everything.
        security.AddAccessRule(new PipeAccessRule(
            new SecurityIdentifier(WellKnownSidType.AuthenticatedUserSid, null),
            PipeAccessRights.ReadWrite, AccessControlType.Allow));
        security.AddAccessRule(new PipeAccessRule(
            new SecurityIdentifier(WellKnownSidType.LocalSystemSid, null),
            PipeAccessRights.FullControl, AccessControlType.Allow));
        security.AddAccessRule(new PipeAccessRule(
            new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid, null),
            PipeAccessRights.FullControl, AccessControlType.Allow));

        return NamedPipeServerStreamAcl.Create(
            Paths.PipeName, PipeDirection.InOut,
            NamedPipeServerStream.MaxAllowedServerInstances,
            PipeTransmissionMode.Byte, PipeOptions.Asynchronous,
            inBufferSize: 0, outBufferSize: 0, pipeSecurity: security);
    }

    private async Task HandleConnectionAsync(NamedPipeServerStream server, CancellationToken ct)
    {
        var req = await Ipc.ReadAsync<PipeRequest>(server, ct);
        if (req is null)
        {
            await Ipc.WriteAsync(server, new PipeResponse { Ok = false, Message = "empty request" }, ct);
            return;
        }

        // Attribute the request to the connecting user (for the audit trail).
        // HARDENING TODO: also verify the caller is our signed agent/client via
        // GetNamedPipeClientProcessId + Authenticode — the peer check.
        string? user = null;
        try { server.RunAsClient(() => user = WindowsIdentity.GetCurrent()?.Name); }
        catch (Exception ex) { _log.LogWarning(ex, "could not resolve caller identity"); }

        PipeResponse resp = req.Command?.ToLowerInvariant() switch
        {
            "ping" => new PipeResponse { Ok = true, Message = $"LaunchRights service alive (SYSTEM), you are {user ?? "?"}" },
            "recent" => new PipeResponse { Ok = true, Message = "ok", Lines = AuditLog.Recent(req.Limit).ToArray() },
            _ => Elevate(req, user),
        };

        await Ipc.WriteAsync(server, resp, ct);
    }

    private PipeResponse Elevate(PipeRequest req, string? user)
    {
        if (string.IsNullOrWhiteSpace(req.ImagePath))
            return new PipeResponse { Ok = false, Message = "no image path" };

        var outcome = Launcher.Elevate(
            req.ImagePath, Allowlist.Load(), source: "win-service",
            requestingUser: user, log: m => _log.LogWarning("{Msg}", m));

        _log.LogInformation("{User} -> {Path}: {Outcome}", user ?? "?", req.ImagePath, outcome.Message);
        return new PipeResponse { Ok = outcome.DidLaunch, Message = outcome.Message };
    }
}
