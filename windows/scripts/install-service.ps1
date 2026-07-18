#Requires -RunAsAdministrator
<#
    Installs the LaunchRights service (LocalSystem) and CLI/agent. Run in an elevated
    PowerShell. Requires the .NET 8 SDK on the build machine.

        .\scripts\install-service.ps1
#>
$ErrorActionPreference = 'Stop'

$Root       = Split-Path -Parent $PSScriptRoot
$InstallDir = Join-Path $env:ProgramFiles 'LaunchRights'
$DataDir    = Join-Path $env:ProgramData  'LaunchRights'

Write-Host '==> Building & publishing (Release)…'
dotnet publish (Join-Path $Root 'src\LaunchRights.Service\LaunchRights.Service.csproj') -c Release -o $InstallDir
dotnet publish (Join-Path $Root 'src\LaunchRights.Run\LaunchRights.Run.csproj')         -c Release -o $InstallDir
dotnet publish (Join-Path $Root 'src\LaunchRights.Agent\LaunchRights.Agent.csproj')      -c Release -o $InstallDir
dotnet publish (Join-Path $Root 'src\LaunchRights.Tray\LaunchRights.Tray.csproj')        -c Release -o $InstallDir

Write-Host '==> Data directory + allowlist…'
New-Item -ItemType Directory -Force -Path $DataDir | Out-Null
$allow = Join-Path $DataDir 'allowlist.json'
if (-not (Test-Path $allow)) {
    Copy-Item (Join-Path $Root 'Resources\allowlist.example.json') $allow
    Write-Host "    wrote example allowlist -> $allow (edit before real use)"
}

# ACL: SYSTEM/Administrators full; standard Users may READ the allowlist but not write.
icacls $DataDir /inheritance:r /grant:r "SYSTEM:(OI)(CI)F" "Administrators:(OI)(CI)F" "Users:(OI)(CI)RX" | Out-Null

# Audit log: SYSTEM/Administrators only — users can neither read nor tamper (matches the mac 0600 log).
$audit = Join-Path $DataDir 'audit.log'
if (-not (Test-Path $audit)) { New-Item -ItemType File -Path $audit | Out-Null }
icacls $audit /inheritance:r /grant:r "SYSTEM:F" "Administrators:F" | Out-Null

Write-Host '==> Registering service (LocalSystem, auto-start)…'
$svcExe = Join-Path $InstallDir 'LaunchRights.Service.exe'
if (Get-Service LaunchRights -ErrorAction SilentlyContinue) {
    Stop-Service LaunchRights -ErrorAction SilentlyContinue
    sc.exe delete LaunchRights | Out-Null
    Start-Sleep -Seconds 1
}
New-Service -Name 'LaunchRights' -BinaryPathName "`"$svcExe`"" `
    -DisplayName 'LaunchRights' -Description 'LaunchRights per-app privilege elevation.' `
    -StartupType Automatic | Out-Null
Start-Service LaunchRights

Write-Host '==> Registering the tray app to start at logon (all users)…'
$trayExe = Join-Path $InstallDir 'LaunchRights.Tray.exe'
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' `
    -Name 'LaunchRights' -Value "`"$trayExe`""

Write-Host ''
Write-Host 'Done. Test with a standard-user shell:'
Write-Host "  & '$InstallDir\LaunchRights.Run.exe' <allowlist-id-or-path>"
Write-Host 'Service log: Event Viewer > Windows Logs > Application (source: LaunchRights)'
Write-Host "Audit log:  $audit  (SYSTEM/Administrators only)"
