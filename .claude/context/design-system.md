---
loaded_by: implementer
unlocks: UI that matches the project's visual tokens and component vocabulary
update_trigger: design.md changes, or a new screen introduces a new component
owned_by: documenter
---

# Design System

Visual polish is explicitly a Phase 5 concern per the spec — but any UI
built in earlier phases (capture UI, nightly review, settings) should still
use these tokens from day one rather than ad hoc values, so Phase 5 is a
refinement pass, not a rewrite.

## Tokens (source: References/design.md)

- Colors: use `Color.accentColor` (primary), `.secondary` (metadata/
  timestamps), `.systemBackground` (surface), `.red` (error/overdue),
  `.green` (success/completed) — never hardcoded hex unless design.md is
  updated first.
- Typography: `.largeTitle` bold for screen titles, `.body` for reminder
  text, `.caption` + `.secondary` for timestamps/confidence hints.
- Spacing: 8pt base unit; 16pt standard padding; 24pt section spacing;
  12pt list row vertical padding.

## Component patterns

- `CaptureButton` — primary capture entry point in-app; always full-width
  or prominent, never buried in a toolbar.
- `ReminderRow` — single reminder display; shows `rawText` (truncated),
  `BucketBadge`, `UrgencyIndicator`, deadline if set.
- `ReviewCard` — nightly review item; accept (default, one tap) and adjust
  (secondary) actions, never more than two actions visible at once.
- `BucketBadge` — small, non-intrusive visual tag; color-coded by bucket.
- `UrgencyIndicator` — low/medium/high; avoid alarming colors for "low".
- `NudgeNotificationAction` — Done / Not yet; must work as a direct
  notification action (no need to open the app).

## Layout conventions

- Nightly review screen: list of `ReviewCard`s, one-tap accept as the
  dominant interaction — this flow must be fast, not thorough per the
  UX principles in the spec.
- Long-horizon items are not shown in the main/daily list until their
  lead-time nudge fires — do not design a "long-horizon tab" that exposes
  them earlier.
