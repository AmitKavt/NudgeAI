---
loaded_by: implementer
unlocks: UI that matches the project's visual tokens and component vocabulary
update_trigger: design.md changes, or a new screen introduces a new component
owned_by: documenter
---

# Design System

Visual polish is explicitly a Phase 6 concern per the spec — but any UI
built in earlier phases (capture UI, nightly review, settings, onboarding)
should still use these tokens from day one rather than ad hoc values, so
Phase 6 is a refinement pass, not a rewrite.

## Tokens (source: References/design.md)

The design is a finished warm/editorial visual system, NOT system colors
— do not use `Color.accentColor`/`.systemBackground`/`.secondary` etc.
Use the explicit hex token set below (via a `Theme`/`Color` extension),
matching the named Figma variables exactly:

- `bg` `#faf7f2` (screen background), `surface` `#ffffff` (cards/rows/tab
  bar), `surface-alt` `#f2eee7` (progress track), `line` `#e7e2d9`
  (dividers/borders)
- `ink` `#1c1917` (primary text), `muted` `#78716c` (secondary text)
- `night` `#1c1917` / `on-night` `#f5f1ea` / `on-night-muted` `#a8a29e` —
  the dark review-summary card on Today
- `accent` `#e8590c` / `accent-soft` `#ffede0` / `accent-night` `#ff7a33`
  / `on-accent` `#ffffff` — primary actions, active tab, progress fill
- `warn` `#b7791f` / `warn-soft` `#fdf1d6` — "to sort"/needs-review
- `success` `#2f7d4f` / `success-soft` `#e3f3e8` — quick-task/completed
- Typography: **Instrument Serif** for display/headline text (screen
  titles, big stat numbers, the nightly-review quote) — a bundled
  non-system font, not SF Pro. **Inter** for everything else (labels,
  buttons, rows, captions, uppercase eyebrows at 11px semibold).
- Spacing: 20pt screen margin; cards 28px corner radius (20px for list
  containers, 16px for buttons, pill/100px for chips); 22-24pt card
  padding; 1px hairline dividers in `line`.
- Light mode only — no dark-mode variants exist in the Figma file.

## Component patterns

- `TabBar` — a custom 5-item pill-shaped bar (Today / Review / **Capture
  mic FAB, raised and circular in the center** / Horizon / You) with a
  drop shadow — NOT a stock SwiftUI `TabView`. The mic button is the
  primary capture entry point, replacing the earlier "CaptureBar as a
  bottom bar on Today" assumption.
- `CaptureButton` — the mic FAB described above, plus the modal capture
  sheet's own mic/send controls.
- `ReminderRow` — single nudge display; shows `rawText` (truncated),
  `BucketBadge`/`StatusChip`, source + time, deadline if set.
- `ReviewCardStack` — the nightly review's swipeable, one-at-a-time card
  ("1 of 3," swipe right = accept, swipe left = skip); shows type,
  urgency, deadline, and confidence %. Never a flat list of buttons.
- `BucketBadge` / `StatusChip` — small, non-intrusive visual tag
  ("Needs review," "Quick task," etc.); color-coded by bucket/status.
- `UrgencyIndicator` — low/medium/high; avoid alarming colors for "low".
- `NudgeNotificationAction` — Done / Not yet; must work as a direct
  notification action (no need to open the app).
- `OfflineBanner` — "Can't reach [provider]" state (not shown with no provider; a quiet dismissible "No AI platform connected" note is used instead); appears on Today, paired
  with a "Paused until [provider] is reachable" note in the review section.
- `OnboardingStepCard` — Welcome / Sign in with Apple / Choose AI platform /
  Teach Siri / Permissions; each shows a progress indicator ("1 of 5," etc).
- `SettingsGroupCard` — grouped rows under a section header (Capture,
  Review, Nudges, AI platform and data).
- `ModelPickerRow` — radio-style Haiku/Sonnet choice with inline cost/
  capability copy, not just a plain picker — the tradeoff must be visible
  at the point of choice.
- `SpendAlertSlider` — monthly spend threshold control, paired with
  "You'll get a warning, never a surprise bill"-style reassurance copy.
- `StatTile` — Profile screen's capture count / review rate / avg capture
  time; three tiles in a row, number-forward.
- `NudgeTrackTimeline` — Long-horizon detail screen's stage-by-stage
  schedule visualization (lead nudge → second nudge → due date), each
  stage labeled with its date and a one-line description.

## Layout conventions

- Nightly review screen: a `ReviewCardStack`, swipe-to-accept as the
  dominant interaction — this flow must be fast, not thorough per the
  UX principles in the spec. Never redesign this as a tap-through list.
- Long-horizon items are not shown in the main/daily Today list until
  their lead-time nudge fires; they live in their own Long-horizon tab,
  split into "Nudging soon" and "Later" sections.
- The custom `TabBar` (Today / Review / Capture / Horizon / You) is the
  app's primary navigation; Settings and the Reminder detail screen are
  pushed/modal destinations reached from within a tab, not tabs
  themselves.
- Onboarding is a linear, full-screen wizard with no tab bar visible —
  it only appears once, before the TabBar is ever shown.
