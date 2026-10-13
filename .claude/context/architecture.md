---
loaded_by: planner, implementer, code-reviewer
unlocks: correct module placement and import boundaries
update_trigger: a new module is added, or a cross-module contract changes
owned_by: documenter
---

# Architecture

## Modules and ownership

- **App** — app entry point, registers the Siri App Intent, hosts the
  TabBar (Today / Long-horizon / You) and routes first-launch to
  Onboarding. Owns nothing else; delegates immediately to Capture/
  Onboarding.
- **Onboarding** — Welcome, Connect Claude, Teach Siri, Permissions
  wizard. Owns: first-launch state (has the wizard completed), handing
  off the API key to Settings/Keychain and permission requests to the
  system frameworks. Runs once; never re-triggered unless the user resets
  the app.
- **Capture** — Siri App Intent handler, in-app capture UI, speech-to-text
  wiring, capture confirmation feedback (haptic/spoken, per Settings).
  Owns: writing raw captured items to Persistence immediately.
  Must never import Classification directly — triggers it via an async
  fire-and-forget call only.
- **Classification** — Claude API client, prompt templates, JSON contract
  parsing, Claude-unreachable state tracking, local spend estimate.
  Owns: turning rawText into bucket/urgency/deadline/confidence. Must
  never touch UI.
- **Review** — nightly review flow and swipeable card-stack UI. Owns:
  querying undated/low-confidence items, swipe-right accept / swipe-left
  skip interaction, surfacing the "paused until Claude is reachable"
  state.
- **Reminders** — long-horizon escalation scheduling logic (recurring
  interval tagging, reschedule-on-incomplete), the Long-horizon tab
  (Nudging soon / Later), and the Reminder detail screen (schedule +
  completion history). Owns: computing `nextNudgeAt` and
  `lastCompletedAt`. Scheduling math is pure logic, no direct UI; the tab
  and detail screens are UI that reads this logic's output.
- **Notifications** — UNUserNotificationCenter scheduling and copy
  generation, quiet-hours delivery holding. Owns: translating a
  ReminderItem's bucket/urgency/deadline/recurringInterval into scheduled
  local notifications, including actionable Done/Not yet buttons.
- **Persistence** — SwiftData `ReminderItem` and `AppSettings` models and
  repositories. Owns: all reads/writes to the data store. Every other
  module reaches Persistence through a repository interface, never raw
  SwiftData queries.
- **Settings** — Anthropic API key entry/replace (Keychain-backed),
  capture confirmation + ambiguous-transcription policy, review time,
  lead times + due-date-check-in toggle, quiet hours, model picker
  (Haiku/Sonnet), monthly spend alert, language. Owns: the only code path
  that writes to the Keychain; everything else it owns lives in
  `AppSettings`.
- **Profile** — stats screen (capture count, one-tap-review rate, avg
  capture time, Claude usage/spend). Owns: aggregating read-only queries
  over Persistence and Classification's spend estimate; writes nothing.

## Import boundaries

- Capture → Persistence (write), Capture → Classification (async trigger
  only, no return-value dependency)
- Classification → Persistence (update after response)
- Review → Persistence (query), Review → Notifications (schedule after
  confirm)
- Reminders → Persistence (query/update), Reminders → Notifications
  (schedule/reschedule)
- Notifications → Persistence (read only, to pull stored copy/metadata),
  Notifications → Settings (read quiet hours, lead times, check-in toggle)
- Settings → Persistence (config only, never ReminderItem data)
- Onboarding → Settings (writes API key via Settings' Keychain path, not
  directly), Onboarding → App (signals first-launch complete)
- Profile → Persistence (read only), Profile → Classification (read spend
  estimate only, never triggers a call)
- No module other than Settings/Classification may read the Keychain —
  Onboarding's API key step still writes through Settings' interface, it
  does not touch the Keychain directly.
- No module may import SwiftUI into logic classified as "pure" (parsing,
  scheduling math, spend estimation) — these must be framework-free and
  unit-testable.

## Domain boundaries this project must never cross (v1)

- No multi-user data model — a single implicit user, no user-switching
  logic anywhere.
- No calendar/email integration code paths.
- No project/sub-task hierarchy on ReminderItem.
- No backend/server or account system — Onboarding's "Connect Claude"
  step talks only to the Keychain and (to validate the key) the Claude
  API directly, never a Nudge-operated server.
