# Builds a local review page for whatever is sitting in the media inbox.
# Reads capture dates, makes small previews, and lets you label everything
# (individually or in bulk) before handing a manifest back to Claude.
#
#   powershell -ExecutionPolicy Bypass -File tools\photo-intake.ps1
#
param([switch]$Quiet, [switch]$Sheet, [switch]$Publish)

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

# --- -Publish: a self-contained page dropped into iCloud, so the batch can
#     be labelled from a phone with nothing running on this machine ---------
if ($Publish) {
  $rev = Join-Path $inbox "_review"
  New-Item -ItemType Directory -Force -Path $rev | Out-Null
  Get-ChildItem $rev -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

  $mob = @()
  for ($k = 0; $k -lt $items.Count; $k++) {
    $it = $items[$k]
    $b64 = ""
    $p = Join-Path $out $it.preview
    if ($it.preview -and (Test-Path $p)) {
      $small = Join-Path $out "m$($k+1).jpg"
      magick $p -resize "440x440>" -quality 68 -strip $small
      $b64 = "data:image/jpeg;base64," + [Convert]::ToBase64String([IO.File]::ReadAllBytes($small))
    }
    $mob += [pscustomobject]@{
      file = $it.file; date = $it.date; taken = $it.taken; fallback = $it.fallback
      kind = $it.kind; thumb = $b64
    }
  }
  $mobJson = ($mob | ConvertTo-Json -Depth 4 -Compress)
  if ($mob.Count -eq 1) { $mobJson = "[$mobJson]" }

  # Pre-render the same 45-minute grouping as static markup. iOS Quick Look (the
  # Files app preview) shows HTML but never runs the script, so a JS-only page
  # comes up blank on the phone. This is what it falls back to.
  $GAPMIN = 45
  $groups = @()
  $cur = $null
  foreach ($m in $mob) {
    $t = $null
    if ($m.taken) { $t = [datetime]::Parse($m.taken) }
    if ($cur -and $t -and $cur.last -and (($t - $cur.last).TotalMinutes -le $GAPMIN)) {
      $cur.items = $cur.items + $m
      $cur.last  = $t
    } else {
      $cur = [pscustomobject]@{ items = @($m); last = $t }
      $groups = $groups + $cur
    }
  }

  $sb = New-Object Text.StringBuilder
  $shotNo = 0
  for ($g = 0; $g -lt $groups.Count; $g++) {
    $gi = $groups[$g]
    # Kept ASCII on purpose: this file has no BOM, so PowerShell 5.1 reads it as
    # ANSI and any literal en-dash here becomes a parse error. Entities instead.
    $dates = @($gi.items | ForEach-Object { [Net.WebUtility]::HtmlEncode($_.date) } | Select-Object -Unique)
    $times = @($gi.items | Where-Object { $_.taken } |
               ForEach-Object { ([datetime]::Parse($_.taken)).ToString("HH:mm") })
    $when = ($dates -join " &ndash; ")
    if ($times.Count) {
      $when += " &middot; " + $times[0]
      if ($times.Count -gt 1) { $when += "&ndash;" + $times[$times.Count - 1] }
    }
    $n = $gi.items.Count
    [void]$sb.Append('<div class="grp"><div class="grp-top">')
    [void]$sb.Append('<span class="gnum">G' + ($g + 1) + '</span>')
    [void]$sb.Append('<span class="grp-when">' + $when + '</span>')
    [void]$sb.Append('<span class="grp-n">' + $n + ' shot' + $(if ($n -eq 1) { '' } else { 's' }) + '</span>')
    [void]$sb.Append('</div><div class="shots">')
    foreach ($it in $gi.items) {
      $shotNo++
      [void]$sb.Append('<div class="shot">')
      if ($it.thumb) { [void]$sb.Append('<img src="' + $it.thumb + '" alt="">') }
      [void]$sb.Append('<div class="shotn">#' + $shotNo + '</div>')
      [void]$sb.Append('<div class="meta"><span>' + [Net.WebUtility]::HtmlEncode($it.kind) + '</span>')
      [void]$sb.Append('<span class="' + $(if ($it.fallback) { 'warn' } else { '' }) + '">' +
                       [Net.WebUtility]::HtmlEncode($it.date) + $(if ($it.fallback) { ' ~' } else { '' }) +
                       '</span></div></div>')
    }
    [void]$sb.Append('</div></div>')
  }

  $mtpl = [IO.File]::ReadAllText((Join-Path $here "mobile-review-template.html"), [Text.Encoding]::UTF8)
  $mtpl = $mtpl.Replace("/*__ITEMS__*/", $mobJson)
  $mtpl = $mtpl.Replace("<!--__GROUPS__-->", $sb.ToString())
  $page = Join-Path $rev "ZX6R photo batch.html"
  [IO.File]::WriteAllText($page, $mtpl, (New-Object Text.UTF8Encoding($false)))

  $stamp = [pscustomobject]@{
    built = (Get-Date).ToString("s"); count = $items.Count
    files = @($items | ForEach-Object { $_.file })
  }
  [IO.File]::WriteAllText((Join-Path $rev "batch.json"),
    ($stamp | ConvertTo-Json -Depth 4), (New-Object Text.UTF8Encoding($false)))

  if (-not $Quiet) {
    Write-Host "Published for phone: $page" -ForegroundColor Green
    Write-Host "  ($([math]::Round((Get-Item $page).Length/1KB)) KB, $($items.Count) file(s))"
  }
  exit 0
}

if (-not $Quiet) { Write-Host "$($items.Count) file(s) ready to review." -ForegroundColor Green }
Start-Process (Join-Path $out "index.html")
exit 0
