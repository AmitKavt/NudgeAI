---
loaded_by: planner, implementer, documenter
unlocks: consistent naming of domain concepts across code, tasks, and docs
update_trigger: a new domain concept is introduced or renamed
owned_by: documenter
---

# Domain Glossary

- **Capture** — the act of logging a reminder with zero required
  structure, via voice (Siri) or voice/text (in-app).
- **Bucket** — the classification category assigned to a reminder:
  `quickTask`, `scheduledTask`, or `longHorizon`.
- **Urgency tier** — `low`, `medium`, or `high`, assigned by the LLM provider
  during classification, or by the user via Adjust. Nil while unsorted.
- **Confidence** — the provider's self-reported confidence (0.0–1.0) in its
  classification of a given item; below a configured threshold, the item
  is flagged for nightly review instead of auto-assigned.
- **Nightly review** — the once-daily, user-configured-time flow that
  surfaces undated or low-confidence items for a one-tap accept/adjust
  decision.
- **Long-horizon reminder** — a reminder with a recurring interval of six
  months, annual, or custom — these skip the daily view and get their own
  escalating notification schedule.
- **Lead-time nudge** — the first of two heads-up notifications before a
  long-horizon item's due date (default 15 days before).
- **Second nudge** — the closer-in heads-up notification before a long-
  horizon item's due date (default 5 days before).
- **Due-date check-in** — the notification on a long-horizon item's due
  date, asking whether it was completed, with Done / Not yet quick
  actions.
- **Recurring interval** — how often a long-horizon item repeats:
  `none`, `sixMonth`, `annual`, or `custom`. `custom`'s actual repeat
  length lives in `customIntervalMonths` — a user-entered value, never
  guessed by the provider or defaulted silently.
- **Pre-structured item** — an item captured via in-app conversational
  capture that already has its bucket/urgency/deadline set at capture
  time, and is therefore excluded from nightly review.
- **Source** — where an item was captured from: `siri` or `inApp`.
- **Nudge** — the user-facing noun for a captured item (what appears in
  UI copy); the underlying SwiftData type remains `ReminderItem` as an
  internal/engineering name only.
- **Quiet hours** — a configured overnight window (default 10 PM–7 AM)
  during which non-urgent notifications are held and delivered once the
  window ends, rather than firing while the user is likely asleep.
- **Spend alert** — a user-configured monthly dollar threshold (default
  $5) that triggers a warning based on a locally tracked spend estimate;
  advisory only, never blocks capture or classification.
- **Provider unreachable** — the app-wide state when a connected
  provider's API call fails outright; surfaced via the Today banner and a paused nightly
  review, cleared automatically once a call succeeds again.
- **Ambiguous-transcription policy** — the user's choice (in Settings)
  for what happens to a capture with low on-device Speech confidence:
  "Save it and flag it" (default) or "Don't save."
- **Pre-structured item** (see above) is set via `isPreStructured`, not
  inferred from `source` — an in-app capture only counts once its
  follow-up flow has actually completed.
- **Nudging soon / Later** — the two sections of the Long-horizon tab:
  "Nudging soon" = inside the first lead-time window of its due date;
  "Later" = everything else.
- **Provider / platform** — the LLM service the user connects with their
  own API key: DeepSeek or Anthropic in v1, or none.
- **No-provider mode** — normal (not an error) state with no platform
  connected: no classification calls, no unreachable banner, items reach
  review unsorted and the user sorts them manually.
- **Unsorted item** — a nudge with nil bucket/urgency awaiting a provider
  or manual sort; shown as "Needs sorting" in review.
- **Adjust** — the review editor where the user sets bucket, urgency,
  deadline and recurring interval; saves with `classifiedBy = manual`.
- **classifiedBy** — `llm` or `manual`; nil while unsorted.
- **Sign in with Apple** — local-only identity; the Apple user identifier
  is kept in the Keychain, never sent to a Nudge server.
