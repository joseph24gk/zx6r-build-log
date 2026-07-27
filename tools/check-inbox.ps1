# Daily check: if the media inbox has files, publish the phone review page
# into iCloud and raise a toast. Nothing needs to be running afterwards -
# the page rides iCloud to your phone and waits.
param([switch]$OpenIfFound, [switch]$NoPublish)

$ErrorActionPreference = "SilentlyContinue"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$cfg  = Get-Content (Join-Path $here "config.json") -Raw | ConvertFrom-Json

$files = @(Get-ChildItem $cfg.inbox -File |
           Where-Object { $_.Extension -match '(?i)\.(heic|jpg|jpeg|png|mov|mp4|m4v)$' })
if ($files.Count -eq 0) { exit 0 }

$n = $files.Count

# build the phone page first, so the notification is already actionable
if (-not $NoPublish) {
  try {
    powershell -ExecutionPolicy Bypass -File (Join-Path $here "photo-intake.ps1") -Publish -Quiet | Out-Null
  } catch { }
}

$msg = "$n file$(if($n -ne 1){'s'}) waiting. Label them on your phone: Files > ZX6R Rebuild > _review."

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
