---
loaded_by: implementer, code-reviewer
unlocks: correct SwiftData model usage and persistence access patterns
update_trigger: the ReminderItem/AppSettings schema changes, or a migration is needed
owned_by: documenter
---

# Data Conventions

## Models

### `ReminderItem`

Fields exactly per SPEC.md data model table:

| Field | Type | Notes |
|---|---|---|
| id | UUID | primary key |
| rawText | String | exactly what the user said or typed |
| createdAt | Date | capture timestamp |
| source | enum | siri \| inApp |
| bucket | enum? | quickTask \| scheduledTask \| longHorizon; nil until classified or sorted manually |
| urgency | enum? | low \| medium \| high; nil until classified or sorted manually |
| classifiedBy | enum? | llm \| manual; nil while unsorted. Review-rate stats count only llm |
| deadline | Date? | nullable |
| recurringInterval | enum? | none \| sixMonth \| annual \| custom |
| customIntervalMonths | Int? | nullable; only set when recurringInterval == custom — the user-chosen repeat length in months. Never inferred/guessed by the provider. |
| confidence | Double? | provider's classification confidence; nil for unsorted and manually sorted items |
| status | enum | open \| completed \| snoozed |
| reviewedAt | Date? | nightly review timestamp, nullable |
| nextNudgeAt | Date? | next scheduled notification, long-horizon items |
| isPreStructured | Bool | true for in-app conversational captures; excludes from nightly review |
| lastCompletedAt | Date? | nullable; set when a long-horizon due-date check-in is marked "Done" |
| transcriptionConfidence | Double? | nullable; on-device Speech confidence, distinct from `confidence` (the provider's classification confidence) |

### `AppSettings`

A single-row configuration model (or UserDefaults-backed struct — either
is acceptable, but access must still go through a `SettingsRepository`
protocol, never ad hoc `UserDefaults` reads scattered across modules):

| Field | Type | Notes |
|---|---|---|
| siriPhrase | String | default "Hey Siri, nudge me" |
| confirmWithHaptic | Bool | default true |
| confirmWithSpokenWord | Bool | default false |
| language | String | locale identifier, e.g. "en-IN" |
| unsureTranscriptionPolicy | enum | saveAndFlag \| dontSave — default saveAndFlag |
| nightlyReviewTime | Date (time-of-day) | default 9:00 PM |
| skipReviewWhenEmpty | Bool | always true in practice; kept as a field for forward-compat |
| leadTimeFirstDays | Int | default 15 |
| leadTimeSecondDays | Int | default 5 |
| dueDateCheckInEnabled | Bool | default true |
| quietHoursEnabled | Bool | default true |
| quietHoursStart | Date (time-of-day) | default 10:00 PM |
| quietHoursEnd | Date (time-of-day) | default 7:00 AM |
| provider | enum | none \| deepseek \| anthropic — default none |
| selectedModel | String | provider-scoped model id (not a Claude-only enum); default is the platform's cheapest |
| appleDisplayName | String? | Sign in with Apple name, if shared |
| monthlySpendAlertThreshold | Double | default 5.0 (USD) |
| onboardingCompleted | Bool | default false |

API keys (one per platform) and the Apple user identifier are **never**
fields on `AppSettings` — they live only in the Keychain, referenced by a stable key identifier if
needed, never copied into SwiftData or UserDefaults.

## Repository pattern

- All reads/writes go through a `ReminderRepository` protocol for
  `ReminderItem` and a `SettingsRepository` protocol for `AppSettings` —
  no module queries `ModelContext`/`UserDefaults` directly except the
  Persistence module's repository implementations.
- Writes on capture are synchronous and immediate (before classification
  call) — this is a hard requirement, not an optimization.
- Classification updates are partial updates to an existing `ReminderItem`
  (by `id`), never a delete+recreate.

## Query conventions

- Nightly review query: `reviewedAt == nil AND (deadline == nil OR
  confidence < threshold)`, excluding `isPreStructured == true` items.
  The `reviewedAt == nil` check is required — without it, an already-
  reviewed item with no deadline (e.g. a quick task) matches `deadline
  == nil` forever and never leaves the queue. (Found via simulator
  validation 2026-10-14; original query omitted this check.)
- Long-horizon due query: `bucket == longHorizon AND nextNudgeAt <= now`.
- Long-horizon tab query: "Nudging soon" = `bucket == longHorizon AND
  nextNudgeAt <= now + leadTimeFirstDays`; "Later" = everything else with
  `bucket == longHorizon`.
- Profile stats queries are read-only aggregates (counts, averages) over
  `ReminderItem` — never materialized as a separate stored field that
  could drift from the source data.

## Custom recurring interval

- `recurringInterval == custom` must never persist with `customIntervalMonths == nil`.
  When the provider or a quick-reply chip tags an item as custom, the UI asks the
  user for the repeat length (months) via a stepper before the item is
  finalized as long-horizon.
- All scheduling math (`NudgeSchedulingLogic.nextCycleDeadline`) reads
  `customIntervalMonths` for `.custom` items rather than guessing a default.

## Migration policy

- Any schema change to `ReminderItem` or `AppSettings` must be additive
  where possible (new optional fields with sensible defaults); destructive
  changes require an explicit SwiftData migration plan, not a silent
  model replacement.
