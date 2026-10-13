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

- Colors: use `Color.accentColor` (primary), `.secondary` (metadata/
  timestamps), `.systemBackground` (surface), `.orange`/`.red`
  (error/overdue/offline banner), `.green` (success/completed/Done) —
  never hardcoded hex unless design.md is updated first.
- Typography: `.largeTitle`/`.title` bold for screen titles, `.body` for
  nudge text and chat bubbles, `.caption` + `.secondary` for timestamps,
  source labels, and section eyebrows.
- Spacing: 8pt base unit; 16–20pt standard padding; 24pt section spacing;
  ~63pt list row height with 1pt dividers (per the Figma row frames).

## Component patterns

- `CaptureButton` / `CaptureBar` — primary capture entry point; a
  persistent bottom bar on Today ("Tap to speak or type a nudge") plus
  the modal capture sheet's mic/send controls.
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
- `OfflineBanner` — "Can't reach Claude" state; appears on Today, paired
  with a "Paused until Claude is reachable" note in the review section.
- `OnboardingStepCard` — Welcome / Connect Claude / Teach Siri /
  Permissions; each shows a progress indicator ("1 of 3," "2 of 3," etc).
- `SettingsGroupCard` — grouped rows under a section header (Capture,
  Review, Nudges, Claude and Data).
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
- The TabBar (Today / Long-horizon / You) is the app's primary
  navigation; Settings and the Reminder detail screen are pushed/modal
  destinations reached from within a tab, not tabs themselves.
- Onboarding is a linear, full-screen wizard with no tab bar visible —
  it only appears once, before the TabBar is ever shown.
