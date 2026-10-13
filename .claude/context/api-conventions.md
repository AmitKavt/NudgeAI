---
loaded_by: implementer, code-reviewer
unlocks: correct, consistent Claude API and inter-module interface design
update_trigger: the Claude API JSON contract changes, or a new inter-module protocol is introduced
owned_by: documenter
---

# API Conventions

## Claude API contract (Classification module)

Model: user-selectable in Settings — **Claude Haiku** (default, per-item
classification and nightly digest) or **Claude Sonnet** (opt-in, applies
to all Claude calls including in-app conversational follow-ups). The
model choice is read from `AppSettings.selectedModel` at call time — it
is never hardcoded or silently overridden per call type in v1.

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
  crash — surface via the Claude-unreachable/paused-review state (never
  retry indefinitely).
- A request that fails outright (network error, timeout, 5xx) sets the
  app-wide "Claude unreachable" state, consumed by the Today banner and
  Review's paused state; it clears automatically once a request succeeds.
- Nightly digest call: one call per day, batches all open low-confidence
  items, same JSON shape per item.

## In-app quick-reply resolution

When the in-app conversational flow asks a follow-up and the user taps a
quick-reply chip ("This week," "This month," "Every 6 months," "No
deadline"), the client resolves that tap to a concrete `deadline` or
`recurring_interval` value **locally** — it does not round-trip back to
Claude to reparse the chip. Claude's role in this flow is limited to
generating the follow-up question and the set of quick-reply options
(a single call), not interpreting the user's selection.

## Spend estimate

Classification maintains a local running total of the current calendar
month's estimated spend: `requests_this_month × per-request cost for
selectedModel`. This feeds the Profile screen's "Claude usage" figure and
the Settings spend-alert comparison. It is an estimate, not a value
fetched from the Anthropic API — there is no Anthropic billing endpoint
call in v1.

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
