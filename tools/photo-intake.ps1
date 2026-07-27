# Builds a local review page for whatever is sitting in the media inbox.
# Reads capture dates, makes small previews, and lets you label everything
# (individually or in bulk) before handing a manifest back to Claude.
#
#   powershell -ExecutionPolicy Bypass -File tools\photo-intake.ps1
#
param([switch]$Quiet, [switch]$Sheet)

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

# --- previews + metadata ---------------------------------------------------
$items = @()
$i = 0
foreach ($f in $files) {
  $i++
  $isVid = $f.Extension -match '(?i)\.(mov|mp4|m4v)$'
  $prev = "p$i.jpg"
  $taken = $null
  try {
    if ($isVid) {
      $j = ffprobe -v quiet -print_format json -show_format $f.FullName | ConvertFrom-Json
      $cd = $j.format.tags.'com.apple.quicktime.creationdate'
      if ($cd) { $taken = [datetime]::Parse($cd) }
      ffmpeg -y -v error -ss 1 -i $f.FullName -frames:v 1 -vf "scale=520:-1" (Join-Path $out $prev) 2>$null
    } else {
      $ex = magick identify -quiet -format "%[EXIF:DateTimeOriginal]" $f.FullName 2>$null
      if ($ex) {
        $p = $ex -split ' '
        $taken = [datetime]::ParseExact(($p[0] -replace ':','-') + " " + $p[1],
                                        "yyyy-MM-dd HH:mm:ss", $null)
      }
      magick $f.FullName -auto-orient -resize "520x520>" -quality 82 -strip (Join-Path $out $prev)
    }
  } catch { }
  $fallback = $false
  if (-not $taken) { $taken = $f.LastWriteTime; $fallback = $true }
  if (-not (Test-Path (Join-Path $out $prev))) { $prev = "" }
  $items += [pscustomobject]@{
    file = $f.Name; preview = $prev
    date = $taken.ToString("yyyy-MM-dd")
    taken = $taken.ToString("yyyy-MM-dd HH:mm:ss")
    fallback = $fallback
    kind = $(if ($isVid) { "video" } else { "photo" })
    size = [math]::Round($f.Length / 1MB, 1)
  }
}

$itemsJson = ($items | ConvertTo-Json -Depth 4 -Compress)
if ($items.Count -eq 1) { $itemsJson = "[$itemsJson]" }

$tpl = [IO.File]::ReadAllText((Join-Path $here "intake-template.html"), [Text.Encoding]::UTF8)
$tpl = $tpl.Replace("/*__ITEMS__*/", $itemsJson)
[IO.File]::WriteAllText((Join-Path $out "index.html"), $tpl, (New-Object Text.UTF8Encoding($false)))

# --- -Sheet: one numbered contact sheet, for describing the batch from your
#     phone (Claude can send it to you in chat; no page, no upload) ----------
if ($Sheet) {
  $tiles = @()
  for ($k = 0; $k -lt $items.Count; $k++) {
    $p = Join-Path $out $items[$k].preview
    if (-not (Test-Path $p)) { continue }
    $tile = Join-Path $out "t$($k+1).jpg"
    magick $p -resize "440x330^" -gravity center -extent 440x330 `
      -fill "#0a0f0dcc" -draw "roundrectangle 8,8 62,48 6,6" `
      -fill "#3fae8c" -pointsize 34 -gravity northwest -annotate +22+12 "$($k+1)" $tile
    $tiles += $tile
  }
  $sheetPath = Join-Path $out "contact-sheet.jpg"
  magick montage $tiles -tile 3x -geometry "+7+7" -background "#0a0f0d" -quality 88 $sheetPath
  Write-Host $sheetPath
  for ($k = 0; $k -lt $items.Count; $k++) {
    Write-Host "$($k+1). $($items[$k].file) - $($items[$k].taken)$(if($items[$k].fallback){' (file date)'})"
  }
  exit 0
}

if (-not $Quiet) { Write-Host "$($items.Count) file(s) ready to review." -ForegroundColor Green }
Start-Process (Join-Path $out "index.html")
exit 0
