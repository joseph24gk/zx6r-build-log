# Photo intake

Drop photos and clips into the iCloud media inbox as usual. Nothing else
about that changes.

## The loop

1. **A daily check** (Windows scheduled task, 6:00 PM) looks in the inbox.
   If anything's there, it raises a notification.
2. **Open the review page** — double-click `Review Photos.cmd`, or run
   `powershell -ExecutionPolicy Bypass -File tools\photo-intake.ps1`.
   It reads every file's capture date, builds a preview of each one
   (including a frame grabbed from each video), and opens a page in your
   browser showing the whole batch.
3. **Label them.** Type what each shot is. Click any photo to select it,
   then use the bar at the top to apply the same description and/or the
   same target event to everything selected at once. Each item can go to:
   - an existing entry (dropdown lists every event, newest first),
   - a standalone gallery shot, or
   - its own new entry.
   Anything missing a capture date is flagged in brass, so a guessed date
   never slips through unnoticed.
4. **Hit Submit.** The manifest lands on your clipboard and downloads as
   `zx6r-intake.json`.
5. **Tell Claude "the batch is ready."** It reads the manifest, converts and
   strips the files, names them by date, wires them into the log's JSON,
   commits, pushes, and clears the inbox.

## Files

| file | what it does |
|---|---|
| `photo-intake.ps1` | scans the inbox, builds previews, generates the review page |
| `intake-template.html` | the review page itself |
| `check-inbox.ps1` | the daily notifier |
| `Review Photos.cmd` | manual trigger |
| `config.json` | local paths (gitignored) |

## Turning the daily check off

```
schtasks /Delete /TN "ZX6R build log - photo inbox check" /F
```

Change the time with `/ST HH:MM` on a `schtasks /Create ... /F` re-run.
