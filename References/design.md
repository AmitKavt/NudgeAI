---
owned_by: documenter
cascades_to: .claude/context/design-system.md
---

# design.md — Nudge AI Design Tokens

Source: Figma file "Nudge AI — iOS Designs"
(https://www.figma.com/design/oB82tlQm7eyDgsMdIuHKjx), 16 screens, synced
2026-10-14 by pulling real node data (`get_design_context`/`get_variable_defs`)
— the file has a finished visual design, not a wireframe; the prior version
of this doc was stale on that point.

## Colors

Figma variable names → hex (warm, editorial, off-white palette — not
system blue/gray):

| Token | Hex | Usage |
|---|---|---|
| `bg` | `#faf7f2` | screen background |
| `surface` | `#ffffff` | cards, rows, tab bar |
| `surface-alt` | `#f2eee7` | progress track background |
| `line` | `#e7e2d9` | hairline dividers, card borders |
| `ink` | `#1c1917` | primary text |
| `muted` | `#78716c` | secondary text, timestamps, captions |
| `night` | `#1c1917` | dark card background (Today's review-summary card) |
| `on-night` | `#f5f1ea` | text on `night` background |
| `on-night-muted` | `#a8a29e` | secondary text on `night` background |
| `accent` | `#e8590c` | primary actions, active tab, progress fill |
| `accent-soft` | `#ffede0` | avatar background, soft accent fills |
| `accent-night` | `#ff7a33` | accent text on `night` background |
| `on-accent` | `#ffffff` | text/icons on accent-filled buttons |
| `warn` | `#b7791f` | "to sort" / needs-review text |
| `warn-soft` | `#fdf1d6` | "to sort" / needs-review chip background |
| `success` | `#2f7d4f` | quick-task / completed text |
| `success-soft` | `#e3f3e8` | quick-task / completed chip background |

No system colors (`.blue`, `.systemBackground`, etc.) anywhere in the
design — implement as an explicit `Color` token set (e.g. `Color("bg")` /
`Color.nudgeBG` asset-catalog or extension), not adaptive system colors.
The design is light-mode only in the file; no dark-mode variants were
designed — ask the developer before inventing one.

## Typography

- **Display/headline**: Instrument Serif, regular weight — screen titles
  ("Today"), the "you said" quote in nightly review, large numeric/stat
  headlines ("3 to sort"). Distinctive, not a system font — bundle
  Instrument Serif in the app if not already (check for a Google Fonts
  OFL license file).
- **UI/body**: Inter — everything else (labels, buttons, rows, captions).
  If Inter isn't bundled, SF Pro is the nearest fallback but is a
  deviation from the design; flag it if substituted.
- Eyebrow labels (`TONIGHT'S REVIEW`, `CAPTURED TODAY`, `YOU SAID`,
  `CLAUDE SUGGESTS`) are Inter Semibold, 11px, uppercase, letter-spaced.

## Spacing & shape

- Screen margin: 20pt
- Card corner radius: 28px (large cards like Today's review summary,
  nightly review card); 20px (list containers); 16px (buttons); 100px /
  pill (status chips)
- Card padding: 22-24pt
- Hairline dividers: 1px, `line` color, full-bleed within card padding
- Row height: content-driven (~63pt with two text lines), 14-16pt
  vertical padding

## Component Names

- `TabBar` — custom 5-item bar (Today / Review / **Capture mic FAB
  raised in the center** / Horizon / You), pill-shaped, `surface`
  background, drop shadow. This is NOT a standard SwiftUI `TabView` —
  it has a floating circular accent-colored mic button as the center
  item, elevated above the bar.
- `CaptureButton` / `CaptureBar` — the mic FAB in the custom tab bar is
  the primary capture entry point (not a separate bottom bar on Today
  as the pre-sync version of this doc assumed)
- `ReminderRow` — single nudge row in a list (Captured Today, Later
  list): title + "Source · time" caption + trailing status chip
- `ReviewCardStack` — the nightly review's swipeable, one-at-a-time
  card; progress bar (segment per item) at top, "N of M" in the nav
  row, "YOU SAID" eyebrow + serif quote, divider, "CLAUDE SUGGESTS"
  eyebrow + Type/Urgency/Deadline/Confidence rows, swipe hint caption,
  primary "Looks right" button + two secondary buttons ("Adjust" /
  "Not today")
- `BucketBadge` / `StatusChip` — pill chips using the warn/success
  color pairs above ("To sort" = warn, "Quick task" = success)
- `UrgencyIndicator` — same pill-chip treatment, warn-colored for High
  seen so far
- `NudgeNotificationAction` — Done / Not yet quick actions on the
  due-date check-in notification
- `OfflineBanner` — "Can't reach Claude" state on Today
- `OnboardingStepCard` — Welcome / Connect Claude / Teach Siri /
  Permissions, each with a progress indicator ("1 of 3")
- `SettingsGroupCard` — grouped rows under a section header (Capture,
  Review, Nudges, Claude and Data)
- `ModelPickerRow` — radio-style Haiku/Sonnet choice with cost copy
- `SpendAlertSlider` — monthly spend threshold control
- `StatTile` — Profile screen's capture count / review rate / avg
  capture time
- `NudgeTrackTimeline` — Long-horizon detail screen's stage-by-stage
  schedule visualization (lead nudge → second nudge → due date)

## Known gap

This sync pulled full fidelity for screens 5 (Today) and 7 (Nightly
review) only. The remaining 14 screens share the same token set per
their component reuse (`Button/Primary`, `Chip/Warn`, etc. are the same
named components across the file) but have not each been individually
pulled and verified pixel-for-pixel. Treat this doc's tokens as
authoritative; treat any screen-specific layout detail not called out
above as needing a follow-up `get_design_context` pull before assuming it
matches.
