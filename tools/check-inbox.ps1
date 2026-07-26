# Daily check: if the media inbox has files, raise a toast.
# Clicking the toast is not wired to anything - use "Review Photos.cmd"
# (or just tell Claude) once you've been nudged.
param([switch]$OpenIfFound)

$ErrorActionPreference = "SilentlyContinue"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$cfg  = Get-Content (Join-Path $here "config.json") -Raw | ConvertFrom-Json

$files = @(Get-ChildItem $cfg.inbox -File |
           Where-Object { $_.Extension -match '(?i)\.(heic|jpg|jpeg|png|mov|mp4|m4v)$' })
if ($files.Count -eq 0) { exit 0 }

$n = $files.Count
$msg = "$n file$(if($n -ne 1){'s'}) waiting for the build log. Run Review Photos to label them."

try {
  [void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
  $ni = New-Object System.Windows.Forms.NotifyIcon
  $ni.Icon = [System.Drawing.SystemIcons]::Information
  $ni.BalloonTipTitle = "ZX-6R build log"
  $ni.BalloonTipText  = $msg
  $ni.Visible = $true
  $ni.ShowBalloonTip(15000)
  Start-Sleep -Seconds 16
  $ni.Dispose()
} catch {
  Write-Host $msg
}

if ($OpenIfFound) {
  powershell -ExecutionPolicy Bypass -File (Join-Path $here "photo-intake.ps1") -Quiet
}
exit 0
