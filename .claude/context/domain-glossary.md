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
- **Urgency tier** — `low`, `medium`, or `high`, assigned by Claude during
  classification.
- **Confidence** — Claude's self-reported confidence (0.0–1.0) in its
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
  `none`, `sixMonth`, `annual`, or `custom`.
- **Pre-structured item** — an item captured via in-app conversational
  capture that already has its bucket/urgency/deadline set at capture
  time, and is therefore excluded from nightly review.
- **Source** — where an item was captured from: `siri` or `inApp`.
