---
loaded_by: implementer, code-reviewer
unlocks: correct, consistent Claude API and inter-module interface design
update_trigger: the Claude API JSON contract changes, or a new inter-module protocol is introduced
owned_by: documenter
---

# API Conventions

## Claude API contract (Classification module)

Model: Claude Haiku for per-item classification and nightly digest.
Mid-tier model only for in-app conversational follow-ups, and only if
testing shows Haiku responses feel too rigid there.

Request: one call per capture — transcribed `rawText` + a system prompt
instructing strict JSON output.

Response contract (must parse exactly, reject/flag anything else):

```json
{
  "bucket": "quick_task | scheduled_task | long_horizon",
  "urgency": "low | medium | high",
  "deadline": "2026-10-20 or null",
  "recurring_interval": "none | monthly | six_month | annual | custom",
  "confidence": 0.0
}
```

- `confidence` below the configured threshold → item is NOT silently
  accepted; it's flagged for nightly review (`reviewedAt` stays null).
- Malformed/unparseable JSON → treat as a classification failure, not a
  crash — surface via the fallback state (see Open Questions in SPEC.md)
  rather than retry indefinitely.
- Nightly digest call: one call per day, batches all open low-confidence
  items, same JSON shape per item.

## Inter-module protocol conventions

- Modules expose capabilities via protocols (e.g. `ClassificationClient`,
  `ReminderRepository`, `NotificationScheduler`), not concrete types, so
  test-engineer can substitute fakes.
- Async boundaries (Capture → Classification, Classification → Persistence
  update) use `async throws` functions — errors are explicit, never
  swallowed.
- No module calls UNUserNotificationCenter or URLSession directly except
  Notifications and Classification respectively — everything else goes
  through those modules' protocol interfaces.
