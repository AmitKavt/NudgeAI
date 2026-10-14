---
loaded_by: implementer, code-reviewer
unlocks: correct, consistent Claude API and inter-module interface design
update_trigger: the Claude API JSON contract changes, or a new inter-module protocol is introduced
owned_by: documenter
---

# API Conventions

## LLM provider contract (Classification module)

All calls go through one provider-neutral protocol; prompts and the JSON
contract below are shared. Each platform has a thin URLSession adapter
(own URL, auth headers, request/response envelope), no provider SDKs:
- **Anthropic:** `/v1/messages`, `x-api-key` + `anthropic-version`, top-
  level `system`, text in `content[].text`.
- **DeepSeek:** OpenAI-compatible `chat/completions`, `Authorization:
  Bearer`, `system` message, text in `choices[0].message.content`
  (verify model IDs/JSON mode against current docs).

A client factory returns `nil` when `AppSettings.provider` is none or no
key is stored; callers then skip classification — not an error, no
unreachable state. Entering a key triggers one minimal key-check request
before "Connected"; failure stores nothing.

Model: user-selectable in Settings from the selected platform's list
(Anthropic: **Claude Haiku** default, **Claude Sonnet** opt-in; DeepSeek:
cheapest chat model default). Read from `AppSettings` (provider + a
provider-scoped model id string) at call time — never hardcoded or
silently overridden per call type. Changing platform resets the model to
that platform's default. Provider-specific names/model IDs live only in
adapters and their model lists.

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
  crash — surface via the provider-unreachable/paused-review state (never
  retry indefinitely).
- A request that fails outright (network error, timeout, 5xx) sets the
  app-wide "provider unreachable" state, consumed by the Today banner and
  Review's paused state; it clears automatically once a request succeeds.
- Nightly digest call: one call per day, batches all open low-confidence
  items, same JSON shape per item.

## In-app quick-reply resolution

When the in-app conversational flow asks a follow-up and the user taps a
quick-reply chip ("This week," "This month," "Every 6 months," "No
deadline"), the client resolves that tap to a concrete `deadline` or
`recurring_interval` value **locally** — it does not round-trip back to
the provider to reparse the chip. The provider's role in this flow is limited to
generating the follow-up question and the set of quick-reply options
(a single call), not interpreting the user's selection.

## Spend estimate

Classification maintains a local running total of the current calendar
month's estimated spend: `requests_this_month × per-request cost for
selected platform + model (pricing kept per platform/model; unknown
pricing shows request count only). This feeds the Profile screen's "AI
usage" figure and
the Settings spend-alert comparison. It is an estimate, not a value
fetched from any provider API — there is no billing endpoint
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
