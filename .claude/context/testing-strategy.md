---
loaded_by: test-engineer
unlocks: knowing what to test, how, and to what coverage bar
update_trigger: testing approach changes, or a new high-risk logic area is added
owned_by: documenter
---

# Testing Strategy

## What to test

- Pure logic only, with unit tests, no UI automation required for v1:
  - Classification JSON contract parsing (valid responses, malformed
    responses, null deadline, every bucket/urgency/recurring_interval
    value)
  - Confidence threshold routing (above threshold → auto-assign, below →
    flagged for nightly review)
  - Nightly review query logic (undated/low-confidence selection,
    exclusion of pre-structured in-app items)
  - Long-horizon notification scheduling math (lead-time offsets, due-date
    check-in timing)
  - Reschedule-on-incomplete logic (recomputing `nextNudgeAt` correctly
    across recurring interval types) and `lastCompletedAt` updates on
    "Done"
  - Quiet-hours delivery holding (a notification due inside the window is
    delayed to the window's end, not dropped)
  - Quick-reply chip resolution (in-app follow-up taps → concrete
    deadline/recurring_interval, with no API round-trip)
  - Local spend estimate math (requests × model pricing, across a model
    switch mid-month)
  - "Long-horizon tab" query logic (Nudging soon vs. Later partitioning)

## What not to test

- SwiftUI view rendering/layout — not worth automated coverage for a
  personal single-user app at this stage.
- Apple's Speech framework transcription accuracy itself (framework
  behavior, not app logic) — validate manually per the Phase 0/1 "validate
  the core moment" step instead.
- Siri App Intent lock-screen/CarPlay behavior — this is explicitly called
  out in the spec as needing hands-on manual testing, not unit tests.

## Forbidden imports in test files

- No `import SwiftUI` in tests for Classification, Reminders, or parsing
  logic — these must be framework-free.
- No live network calls in tests — the Claude API client must be
  substitutable with a fake/mock conforming to its protocol.

## Coverage expectations

- Every public function in Classification, Reminders, and Notifications
  scheduling logic has at least one test covering its primary path and at
  least one covering an edge case (null/malformed input, boundary dates).
- No fixed percentage target — coverage is reported per task, and gaps in
  the areas above block handoff to code-reviewer.
