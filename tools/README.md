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
3. **Label them.** The batch arrives **pre-grouped by when the shots were
   taken** — anything within 45 minutes of the last one lands in the same
   group — so you write one description per group instead of per photo.
   If a grouping is wrong, hit `split here` on a photo to break the group
   at that point, or `⇈ merge up` to fold a group into the one above it.
   You never say where a photo belongs in the log; Claude works that out
   from the description and the date. Anything missing a capture date is
   flagged in brass, so a guessed date never slips through unnoticed.
4. **Hit Submit.** The manifest lands on your clipboard and downloads as
   `zx6r-intake.json`.
5. **Tell Claude "the batch is ready."** It reads the manifest, converts and
   strips the files, names them by date, wires them into the log's JSON,
   commits, pushes, and clears the inbox.

## Away from the computer

The photos only exist on the PC and in iCloud until they're published, so
there's no page on the public site that could show them to you and nobody
else — a static site can't keep a secret. Two things that do work:

- **Ask Claude for the contact sheet.** It runs `photo-intake.ps1 -Sheet`,
  which builds one numbered image of the whole batch, and sends it to you
  in chat. Reply with plain text — *"1–2 are the tires on the machine,
  3 is the fender, 4–5 the rearset"* — and it takes over from there.
- **Just describe them.** Open the folder in the Files app on your phone
  and tell Claude what's in it. Nothing has to be uploaded anywhere.

Either way the batch waits in the inbox until you get to it.

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
