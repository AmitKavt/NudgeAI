---
owned_by: documenter
do_not_edit_manually: true — edit NudgeAI_Spec.md instead
---

# SPEC.md — Nudge AI Operating Brief

## Summary

Nudge AI lets the user capture a reminder with zero structure (voice via
Siri, or voice/text in-app). Claude classifies each item afterward into a
bucket, urgency tier, and optional deadline. Short-horizon items go through
a one-tap nightly review when undated; long-horizon items get a
three-stage escalating notification sequence.

## Module Responsibilities

- **App** — app entry point, registers the Siri App Intent.
- **Capture** — Siri capture intent (raw text + timestamp, no questions),
  in-app capture UI (text or speech), on-device transcription.
- **Classification** — calls Claude API with captured text, parses the
  strict JSON contract (bucket, urgency, deadline, recurring_interval,
  confidence), flags low-confidence results for nightly review.
- **Review** — nightly review flow: surfaces undated/low-confidence items,
  one-tap accept/adjust.
- **Reminders** — long-horizon escalation scheduling: recurring interval
  tagging, reschedule-on-incomplete logic.
- **Notifications** — schedules local notifications (short-horizon single
  notification; long-horizon three-stage sequence; nightly review digest
  notification); generates and stores copy once at classification time.
- **Persistence** — SwiftData `ReminderItem` model and repositories;
  immediate local write before any network call.
- **Settings** — Anthropic API key entry (Keychain-backed), configurable
  lead times (default 15/5 days), configurable nightly review time.

## Protocol / API Contracts Between Modules

- Capture → Persistence: every captured item is written to SwiftData
  immediately as `ReminderItem` with `rawText`, `createdAt`, `source`,
  `status: open`, before any classification call.
- Capture → Classification: fire-and-forget async call after the local
  write; never blocks the capture UI.
- Classification → Claude API: system prompt + rawText → strict JSON
  `{bucket, urgency, deadline, recurring_interval, confidence}`.
- Classification → Persistence: updates the `ReminderItem` with
  classification results; if `confidence` below threshold, leaves
  `reviewedAt` null so it surfaces in nightly Review.
- Review → Notifications: once a bucket/deadline is confirmed, Review
  module hands off to Notifications to schedule the appropriate sequence.
- Reminders → Notifications: long-horizon items register a three-stage
  notification sequence (lead nudge, second nudge, due-date check-in);
  on "Not yet" action, Reminders recomputes `nextNudgeAt` and re-registers.
- Settings → all modules: API key read from Keychain by Classification;
  lead-time and review-time config read by Reminders and Review
  respectively.

## Out of Scope

- No multi-user support or sharing of reminders.
- No cross-platform support; iOS only for v1.
- No calendar or email integration in v1.
- No complex project or sub-task management.

## Done Criteria Per Phase

- **Phase 0:** project builds with zero errors, no feature code.
- **Phase 1:** Siri App Intent captures speech and writes a `ReminderItem`
  to SwiftData with zero required input beyond the spoken text; works with
  phone locked.
- **Phase 2:** every captured item gets classified via Claude API;
  low-confidence items appear in a working nightly review flow with
  one-tap accept.
- **Phase 3:** in-app conversational capture asks up to two follow-up
  questions and produces an already-structured item, excluded from
  nightly review.
- **Phase 4:** long-horizon items run the full three-stage notification
  sequence and reschedule correctly on incompletion.
- **Phase 5:** configurable lead times and review time exposed in
  Settings; visual polish applied.
