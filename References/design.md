---
owned_by: documenter
cascades_to: .claude/context/design-system.md
---

# design.md — Nudge AI Design Tokens

The PRD does not specify visual design in detail (polish is explicitly
deferred to Phase 5). These are sensible defaults to unblock early UI work;
revise once real usage patterns inform the final look.

## Colors

- Primary: system blue (`.blue` / `Color.accentColor`) — used for primary
  actions (capture button, accept in review)
- Secondary: system gray (`.secondary`) — timestamps, metadata
- Surface: system background (`.systemBackground` / adaptive light/dark)
- Error: system red (`.red`) — failed classification, overdue items
- Success: system green (`.green`) — completed items, accepted review items

## Typography

- Title: SF Pro, `.largeTitle`, bold — screen headers
- Body: SF Pro, `.body` — reminder text, review items
- Caption: SF Pro, `.caption`, secondary color — timestamps, confidence hints

## Spacing

- Base unit: 8pt
- Standard padding: 16pt (2x base)
- Section spacing: 24pt (3x base)
- List row vertical padding: 12pt

## Component Names

- `CaptureButton` — primary capture entry point in-app
- `ReminderRow` — single reminder display (list/review contexts)
- `ReviewCard` — nightly review item with accept/adjust actions
- `BucketBadge` — visual indicator for quick/scheduled/long-horizon
- `UrgencyIndicator` — low/medium/high visual marker
- `NudgeNotificationAction` — Done / Not yet quick actions
