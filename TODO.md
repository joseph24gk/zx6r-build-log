# Build log — TODO / design backlog

Captured 2026-07-24. Ordered roughly by Joseph's priority.

## 1. Timeline: scrap the vertical redesign, go horizontal

The vertical card-stack upgrade missed the goal. The real goal: **stop
overwhelming the reader with vertical scrolling.**

Wanted instead:

- A **horizontal timeline** — a responsive dotted line running left→right.
- **Colored dots** along its length (color = category, as now).
- **Hover magnification**: dots swell as the cursor passes, like the macOS
  Dock — neighbors scale slightly too, falling off with distance.
- **Click a dot → expands that event** (detail panel below/beside the line,
  not a jump to a wall of cards).
- **Keyboard reading**: arrow keys step backward/forward through events so
  the whole log can be read straight through without scrolling. Open to a
  better mechanism if one exists.
- **Minimal annotations only**: maybe dates, maybe ticks on the line for
  something meaningful. Sparse, not labeled to death.
- Priority is "super responsive + visual" over information density.

Also remove/replace, from the rejected upgrade:

- ~~Hex bolt-node torque-in animation~~ — done, removed 2026-07-24.
- Reassess whether hero cards / fold-down cards survive the horizontal
  rework, or get replaced by the expand-on-click panel.

## 2. Color palette rework (donut + timeline + category colors)

Current palette leans too hard on gold / tan / brown. Keep the idea of
**distinct colors per system/category** — just not these.

- Drop or heavily reduce: `--cat-purchase` (#d8b46a), `--cat-tools`
  (#b58a4f), `--cat-decision` (#d9cfae), and the matching donut system
  colors (fuel #d8b46a, wheels #b58a4f, consumables #d9cfae).
- Needs a fresh set that still reads against the emerald/pit background and
  keeps enough separation for ~9 systems + 10 categories.
- Ask Joseph for direction (cooler? more saturated? specific hues he likes)
  before picking — do not guess a palette and ship it.

## 3. Spend modal: "Over time" view

The cumulative-spend chart is cool but noticeably less useful than the
Breakdown view. Options: demote it (breakdown stays default, already true),
rethink what it shows, or cut it entirely. Decide later — no rush.

## Done 2026-07-24

- Donut hover readout removed; interaction is click/tap only.
- "view event ↳" text button → calendar icon only, no text.
- Hex bolt torque-in + hover socket-turn animations removed.
