---
loaded_by: implementer, code-reviewer
unlocks: correct SwiftData model usage and persistence access patterns
update_trigger: the ReminderItem schema changes, or a migration is needed
owned_by: documenter
---

# Data Conventions

## Model

Single SwiftData model: `ReminderItem`. Fields exactly per SPEC.md data
model table:

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

## Repository pattern

- All reads/writes go through a `ReminderRepository` protocol —
  no module queries `ModelContext` directly except the Persistence
  module's repository implementation.
- Writes on capture are synchronous and immediate (before classification
  call) — this is a hard requirement, not an optimization.
- Classification updates are partial updates to an existing `ReminderItem`
  (by `id`), never a delete+recreate.

## Query conventions

- Nightly review query: `deadline == nil OR confidence < threshold`,
  excluding items with `source == inApp` structured flag already set
  (in-app conversational captures skip nightly review entirely — model
  this with an explicit `isPreStructured: Bool` or equivalent, not by
  inferring from `source`).
- Long-horizon due query: `bucket == longHorizon AND nextNudgeAt <= now`.

## Migration policy

- Any schema change to `ReminderItem` must be additive where possible
  (new optional fields); destructive changes require an explicit
  SwiftData migration plan, not a silent model replacement.
