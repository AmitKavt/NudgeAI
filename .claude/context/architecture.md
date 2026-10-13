---
loaded_by: planner, implementer, code-reviewer
unlocks: correct module placement and import boundaries
update_trigger: a new module is added, or a cross-module contract changes
owned_by: documenter
---

# Architecture

## Modules and ownership

- **App** — app entry point, registers the Siri App Intent. Owns nothing
  else; delegates immediately to Capture.
- **Capture** — Siri App Intent handler, in-app capture UI, speech-to-text
  wiring. Owns: writing raw captured items to Persistence immediately.
  Must never import Classification directly — triggers it via an async
  fire-and-forget call only.
- **Classification** — Claude API client, prompt templates, JSON contract
  parsing. Owns: turning rawText into bucket/urgency/deadline/confidence.
  Must never touch UI.
- **Review** — nightly review flow and UI. Owns: querying undated/low-
  confidence items, one-tap accept/adjust interaction.
- **Reminders** — long-horizon escalation scheduling logic (recurring
  interval tagging, reschedule-on-incomplete). Owns: computing
  `nextNudgeAt`. Pure logic, no direct UI.
- **Notifications** — UNUserNotificationCenter scheduling and copy
  generation. Owns: translating a ReminderItem's bucket/urgency/deadline/
  recurringInterval into scheduled local notifications.
- **Persistence** — SwiftData `ReminderItem` model and repositories. Owns:
  all reads/writes to the data store. Every other module reaches
  Persistence through a repository interface, never raw SwiftData queries.
- **Settings** — Anthropic API key entry (Keychain-backed), configurable
  lead times, configurable nightly review time. Owns: the only code path
  that writes to the Keychain.

## Import boundaries

- Capture → Persistence (write), Capture → Classification (async trigger
  only, no return-value dependency)
- Classification → Persistence (update after response)
- Review → Persistence (query), Review → Notifications (schedule after
  confirm)
- Reminders → Persistence (query/update), Reminders → Notifications
  (schedule/reschedule)
- Notifications → Persistence (read only, to pull stored copy/metadata)
- Settings → Persistence (config only, never ReminderItem data)
- No module other than Settings/Classification may read the Keychain.
- No module may import SwiftUI into logic classified as "pure" (parsing,
  scheduling math) — these must be framework-free and unit-testable.

## Domain boundaries this project must never cross (v1)

- No multi-user data model — a single implicit user, no user-switching
  logic anywhere.
- No calendar/email integration code paths.
- No project/sub-task hierarchy on ReminderItem.
