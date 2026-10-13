---
owned_by: documenter
do_not_edit_manually: true — edit NudgeAI_Spec.md instead
---

# SPEC.md — Nudge AI Operating Brief

## Summary

Nudge AI lets the user capture a reminder ("nudge") with zero structure
(voice via Siri, or voice/text in-app). Claude classifies each item
afterward into a bucket, urgency tier, and optional deadline.
Short-horizon items go through a one-tap (swipe) nightly review when
undated; long-horizon items get a three-stage escalating notification
sequence with a dedicated tab and detail screen. The app also includes a
guided onboarding flow, a full Settings surface, and a Profile/stats
screen — all in scope for v1.

## Module Responsibilities

- **App** — app entry point, registers the Siri App Intent, hosts the
  TabBar (Today / Long-horizon / You) and the onboarding flow on first
  launch.
- **Onboarding** — Welcome, Connect Claude (API key entry), Teach Siri
  your phrase, Permissions (mic, speech, notifications) — a one-time,
  three-step wizard.
- **Capture** — Siri capture intent (raw text + timestamp, no questions),
  in-app capture UI (text or speech, quick-reply follow-ups), on-device
  transcription, capture confirmation feedback (haptic/spoken, per
  Settings).
- **Classification** — calls Claude API with captured text, parses the
  strict JSON contract (bucket, urgency, deadline, recurring_interval,
  confidence), flags low-confidence results for nightly review, tracks
  the Claude-unreachable state.
- **Review** — nightly review flow: swipeable card stack of undated/
  low-confidence items, swipe-right accept / swipe-left skip.
- **Reminders** — long-horizon escalation scheduling: recurring interval
  tagging, reschedule-on-incomplete logic, Long-horizon tab (Nudging
  soon / Later), Reminder detail screen with completion history.
- **Notifications** — schedules local notifications (short-horizon single
  notification; long-horizon three-stage sequence with Done/Not yet
  actions; nightly review digest notification), honors quiet hours,
  generates and stores copy once at classification time.
- **Persistence** — SwiftData `ReminderItem` model and repositories;
  immediate local write before any network call; `AppSettings`
  configuration storage.
- **Settings** — API key entry/replace (Keychain-backed), Siri phrase,
  capture confirmation toggles, ambiguous-transcription policy, nightly
  review time, lead times, due-date check-in toggle, quiet hours, model
  picker (Haiku/Sonnet), monthly spend alert, language.
- **Profile** — capture stats (count, one-tap-review rate, avg capture
  time), Claude usage/spend this month, links to Settings/Siri
  phrase/Help.

## Protocol / API Contracts Between Modules

- Capture → Persistence: every captured item is written to SwiftData
  immediately as `ReminderItem` with `rawText`, `createdAt`, `source`,
  `status: open`, before any classification call.
- Capture → Classification: fire-and-forget async call after the local
  write; never blocks the capture UI.
- Classification → Persistence: updates the `ReminderItem` with
  classification results; if `confidence` below threshold, leaves
  `reviewedAt` null so it surfaces in nightly Review.
- Classification → App (Today banner): on API unreachability, surfaces a
  state consumed by the Today screen banner and the Review module's
  "paused" state — no silent retry loop.
- Review → Notifications: once a bucket/deadline is confirmed via swipe,
  Review hands off to Notifications to schedule the appropriate sequence.
- Reminders → Notifications: long-horizon items register a three-stage
  notification sequence; on "Not yet," Reminders recomputes `nextNudgeAt`
  and re-registers; on "Done," Reminders sets `lastCompletedAt` and
  schedules the next cycle.
- Notifications → Settings: reads quiet-hours window to hold/delay
  delivery; reads lead times and due-date-check-in enabled flag.
- Settings → all modules: API key and model choice read by
  Classification; capture confirmation + ambiguous-transcription policy
  read by Capture; review time read by Review; lead times/quiet
  hours/check-in toggle read by Reminders and Notifications.
- Classification → Profile: running spend estimate consumed by the
  Profile screen's Claude usage figure.

## Out of Scope

- No multi-user support or sharing of reminders.
- No cross-platform support; iOS only for v1.
- No calendar or email integration in v1.
- No complex project or sub-task management.
- No Nudge backend/server or account system.

## Done Criteria Per Phase

- **Phase 0:** project builds with zero errors, no feature code.
- **Phase 1:** Siri App Intent captures speech and writes a `ReminderItem`
  to SwiftData with zero required input beyond the spoken text; works with
  phone locked.
- **Phase 2:** every captured item gets classified via Claude API;
  low-confidence items appear in a working swipeable nightly review flow;
  Claude-unreachable banner and paused-review state work end-to-end.
- **Phase 3:** in-app conversational capture asks up to two quick-reply
  follow-up questions and produces an already-structured item, excluded
  from nightly review.
- **Phase 4:** long-horizon items run the full three-stage notification
  sequence, reschedule correctly on incompletion, and are browsable via
  the Long-horizon tab and Reminder detail screen with history.
- **Phase 5:** onboarding (Welcome/Connect Claude/Teach Siri/Permissions),
  full Settings (all four groups and sub-screens), and Profile/stats
  screen are implemented and wired to real data.
- **Phase 6:** visual polish pass and spend-estimate accuracy tuning,
  based on real usage patterns from earlier phases.
