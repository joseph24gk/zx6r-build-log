# Builds a local review page for whatever is sitting in the media inbox.
# Reads capture dates, makes small previews, and lets you label everything
# (individually or in bulk) before handing a manifest back to Claude.
#
#   powershell -ExecutionPolicy Bypass -File tools\photo-intake.ps1
#
param([switch]$Quiet)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$cfg  = Get-Content (Join-Path $here "config.json") -Raw | ConvertFrom-Json
$inbox = $cfg.inbox
$repo  = $cfg.repo

$env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
            [Environment]::GetEnvironmentVariable("Path","User")

$files = @(Get-ChildItem $inbox -File -ErrorAction SilentlyContinue |
           Where-Object { $_.Extension -match '(?i)\.(heic|jpg|jpeg|png|mov|mp4|m4v)$' } |
           Sort-Object LastWriteTime)

if ($files.Count -eq 0) {
  if (-not $Quiet) { Write-Host "Inbox is empty - nothing to review." -ForegroundColor Yellow }
  exit 2
}

$out = Join-Path $env:TEMP "zx6r-intake"
if (Test-Path $out) { Remove-Item "$out\*" -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $out | Out-Null

# --- existing events, so photos can be attached to one ---------------------
$html = [IO.File]::ReadAllText((Join-Path $repo "index.html"), [Text.Encoding]::UTF8)
$events = @()
if ($html -match '(?s)<script type="application/json" id="build-data">\s*(.*?)\s*</script>') {
  $data = $Matches[1] | ConvertFrom-Json
  $events = $data.events | Sort-Object date -Descending | ForEach-Object {
    [pscustomobject]@{ id = $_.id; date = $_.date; title = $_.title }
  }
}

# --- previews + metadata ---------------------------------------------------
$items = @()
$i = 0
foreach ($f in $files) {
  $i++
  $isVid = $f.Extension -match '(?i)\.(mov|mp4|m4v)$'
  $prev = "p$i.jpg"
  $date = ""
  try {
    if ($isVid) {
      $j = ffprobe -v quiet -print_format json -show_format $f.FullName | ConvertFrom-Json
      $cd = $j.format.tags.'com.apple.quicktime.creationdate'
      if ($cd) { $date = ([datetime]::Parse($cd)).ToString("yyyy-MM-dd") }
      ffmpeg -y -v error -ss 1 -i $f.FullName -frames:v 1 -vf "scale=520:-1" (Join-Path $out $prev) 2>$null
    } else {
      $ex = magick identify -quiet -format "%[EXIF:DateTimeOriginal]" $f.FullName 2>$null
      if ($ex) { $date = ($ex -split ' ')[0] -replace ':','-' }
      magick $f.FullName -auto-orient -resize "520x520>" -quality 82 -strip (Join-Path $out $prev)
    }
  } catch { }
  $fallback = $false
  if (-not $date) { $date = $f.LastWriteTime.ToString("yyyy-MM-dd"); $fallback = $true }
  if (-not (Test-Path (Join-Path $out $prev))) { $prev = "" }
  $items += [pscustomobject]@{
    file = $f.Name; preview = $prev; date = $date; fallback = $fallback
    kind = $(if ($isVid) { "video" } else { "photo" })
    size = [math]::Round($f.Length / 1MB, 1)
  }
}

$itemsJson  = ($items  | ConvertTo-Json -Depth 4 -Compress)
$eventsJson = ($events | ConvertTo-Json -Depth 4 -Compress)
if ($items.Count -eq 1)  { $itemsJson  = "[$itemsJson]" }
if ($events.Count -eq 1) { $eventsJson = "[$eventsJson]" }

$tpl = [IO.File]::ReadAllText((Join-Path $here "intake-template.html"), [Text.Encoding]::UTF8)
$tpl = $tpl.Replace("/*__ITEMS__*/",  $itemsJson).Replace("/*__EVENTS__*/", $eventsJson)
[IO.File]::WriteAllText((Join-Path $out "index.html"), $tpl, (New-Object Text.UTF8Encoding($false)))

if (-not $Quiet) { Write-Host "$($items.Count) file(s) ready to review." -ForegroundColor Green }
Start-Process (Join-Path $out "index.html")
exit 0
