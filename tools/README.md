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

## From your phone (nothing running on the PC)

The daily check also writes a **self-contained review page into iCloud**, so
the batch is labellable from anywhere with no live session, no remote
control, and nothing published to the public site.

1. On your phone: **Files ▸ iCloud Drive ▸ Documents ▸ Media ▸ ZX6R Rebuild
   ▸ _review ▸ `ZX6R photo batch.html`** — tap it.
2. The thumbnails are baked into the file itself, so it works offline and
   needs nothing else. Same grouping, same split/merge.
3. Tap **Done**, then either:
   - **Save to Files** → **iCloud Drive ▸ Downloads**. It syncs back to the
     PC and Claude picks it up, or
   - **Copy** and paste it into a chat.

Regenerate it any time with:

```
powershell -ExecutionPolicy Bypass -File tools\photo-intake.ps1 -Publish
```

`-Sheet` is still there if you'd rather just get one numbered image in chat
and reply in plain text (*"1–2 tires, 3 the fender"*).

The `_review` folder is ignored by the intake scan, and gets cleared once a
batch is processed.

## Files

| file | what it does |
|---|---|
| `photo-intake.ps1` | scans the inbox, builds previews, generates the review pages (`-Publish` for the phone copy, `-Sheet` for a contact sheet) |
| `intake-template.html` | the desktop review page |
| `mobile-review-template.html` | the phone page dropped into iCloud |
| `check-inbox.ps1` | daily notifier; also publishes the phone page |
| `Review Photos.cmd` | manual trigger |
| `config.json` | local paths (gitignored) |

## Turning the daily check off

```
schtasks /Delete /TN "ZX6R build log - photo inbox check" /F
```

Change the time with `/ST HH:MM` on a `schtasks /Create ... /F` re-run.
