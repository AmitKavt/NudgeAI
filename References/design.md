---
owned_by: documenter
cascades_to: .claude/context/design-system.md
---

# design.md — Nudge AI Design Tokens

Source: Figma file "Nudge AI — iOS Designs"
(https://www.figma.com/design/oB82tlQm7eyDgsMdIuHKjx), 16 screens, synced
2026-10-13.

## Colors

The Figma file is a wireframe-level pass (no final hex values annotated
yet) — these are the working defaults until a visual design pass assigns
final values in Phase 6:

- Primary: system blue (`.blue` / `Color.accentColor`) — capture button,
  "Start review," accept actions, Siri orb accent
- Secondary: system gray (`.secondary`) — timestamps, metadata, captions
- Surface: system background (`.systemBackground`, adaptive light/dark)
- Error/warning: system orange or red — "Can't reach Claude" banner,
  overdue items
- Success: system green — "Saved" confirmations, completed items, Done
  action

## Typography

- Title: SF Pro, `.largeTitle`/`.title`, bold — screen headers ("Today,"
  "Long-horizon," "Settings")
- Body: SF Pro, `.body` — nudge text, chat bubbles, row titles
- Caption: SF Pro, `.caption`, secondary color — timestamps, source
  labels ("Siri · 8:42 AM"), section eyebrows ("CAPTURED TODAY," "NUDGING
  SOON")

## Spacing

- Base unit: 8pt
- Standard padding: 16–20pt (matches Figma's 20pt screen margins)
- Section spacing: 24pt
- List row height: ~63pt (per Figma row frames), with 1pt dividers

## Component Names

- `CaptureButton` / `CaptureBar` — persistent bottom bar on Today ("Tap
  to speak or type a nudge") and the modal capture sheet's mic/send
  controls
- `ReminderRow` — single nudge row in a list (Captured Today, Later list)
- `ReviewCardStack` — the nightly review's swipeable, one-at-a-time card
  ("1 of 3," swipe right/left)
- `BucketBadge` / `StatusChip` — "Needs review," "Quick task," etc.
- `UrgencyIndicator` — low/medium/high visual marker
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
