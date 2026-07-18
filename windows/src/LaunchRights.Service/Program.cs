using LaunchRights.Service;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

// LaunchRights service — runs as LocalSystem (the Windows analogue of the macOS
// root LaunchDaemon). Listens on a named pipe, validates each request against the
// root-owned allowlist + Authenticode, and launches approved apps elevated.

var builder = Host.CreateApplicationBuilder(args);
builder.Services.AddWindowsService(options => options.ServiceName = "LaunchRights");
builder.Services.AddHostedService<ElevationPipeServer>();

var host = builder.Build();
host.Run();
