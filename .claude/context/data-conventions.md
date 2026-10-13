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
| bucket | enum | quickTask \| scheduledTask \| longHorizon |
| urgency | enum | low \| medium \| high |
| deadline | Date? | nullable |
| recurringInterval | enum? | none \| sixMonth \| annual \| custom |
| confidence | Double | Claude's classification confidence |
| status | enum | open \| completed \| snoozed |
| reviewedAt | Date? | nightly review timestamp, nullable |
| nextNudgeAt | Date? | next scheduled notification, long-horizon items |
| isPreStructured | Bool | true for in-app conversational captures; excludes from nightly review |
| lastCompletedAt | Date? | nullable; set when a long-horizon due-date check-in is marked "Done" |
| transcriptionConfidence | Double? | nullable; on-device Speech confidence, distinct from `confidence` (Claude's classification confidence) |

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
| selectedModel | enum | haiku \| sonnet — default haiku |
| monthlySpendAlertThreshold | Double | default 5.0 (USD) |
| onboardingCompleted | Bool | default false |

The Anthropic API key itself is **never** a field on `AppSettings` — it
lives only in the Keychain, referenced by a stable key identifier if
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

- Nightly review query: `deadline == nil OR confidence < threshold`,
  excluding `isPreStructured == true` items.
- Long-horizon due query: `bucket == longHorizon AND nextNudgeAt <= now`.
- Long-horizon tab query: "Nudging soon" = `bucket == longHorizon AND
  nextNudgeAt <= now + leadTimeFirstDays`; "Later" = everything else with
  `bucket == longHorizon`.
- Profile stats queries are read-only aggregates (counts, averages) over
  `ReminderItem` — never materialized as a separate stored field that
  could drift from the source data.

## Migration policy

- Any schema change to `ReminderItem` or `AppSettings` must be additive
  where possible (new optional fields with sensible defaults); destructive
  changes require an explicit SwiftData migration plan, not a silent
  model replacement.
