#Requires -RunAsAdministrator
# Removes the LaunchRights service and installed binaries. Run elevated.
$ErrorActionPreference = 'SilentlyContinue'

$InstallDir = Join-Path $env:ProgramFiles 'LaunchRights'

Write-Host '==> Stopping & deleting service…'
Stop-Service LaunchRights -ErrorAction SilentlyContinue
sc.exe delete LaunchRights | Out-Null

Write-Host '==> Removing tray autostart…'
Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -Name 'LaunchRights' -ErrorAction SilentlyContinue
Get-Process LaunchRights.Tray -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

Write-Host '==> Removing binaries…'
Remove-Item $InstallDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "    Left $($env:ProgramData)\LaunchRights (allowlist + audit log) in place."
Write-Host 'Done.'
