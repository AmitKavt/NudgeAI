# Nudge AI — Product Spec

> This is the file you (Amit) edit directly. Whenever the product changes,
> update this file, then run the documenter to cascade changes into SPEC.md
> and TASKS.md.

## Overview

Nudge AI is a native iOS app that removes the friction between having a
thought worth remembering and actually capturing it. Amit currently avoids
writing reminders down because every reminder forces an immediate decision:
how important is this, and when does it matter? That upfront categorization
burden is the core problem, not forgetfulness.

Nudge AI separates capture from classification. The user speaks or types a
reminder with zero structure required. Claude, via the Anthropic API,
classifies it afterward into a bucket (quick task, scheduled task, or
long-horizon reminder), assigns an urgency tier, and if useful, a deadline.
The app is accessible hands-free through a custom Siri phrase for on-the-go
capture, and has a richer in-app mode for structured capture with Claude
asking clarifying questions live.

The secondary failure mode this spec actively designs against: Amit has
built a personal app before (SpotSyk) that ended up underused because
day-to-day friction made it easier to not open it. Every design decision
here is evaluated against one question: does this reduce the two-second
cost of capturing a thought, or does it add a step?

## Persona

Just Amit — single user, personal daily-use tool. No multi-user design
needed for v1.

## Goals

- Zero-judgment capture: logging a reminder never requires choosing a
  category, priority, or deadline at the moment of capture.
- Hands-free capture via a custom Siri phrase, usable without unlocking
  or opening the phone.
- Claude-driven classification into buckets and urgency tiers, run
  asynchronously after capture.
- A nightly review flow inside the app for short-horizon, undated items
  that need a deadline or priority decision.
- A separate escalating notification workflow for long-horizon reminders
  (recurring annually, every six months, etc.), with reminders at
  configurable lead times (e.g. 15 days and 5 days out) and a completion
  check-in.
- An in-app conversational capture mode where Claude asks clarifying
  questions live, so those items skip nightly triage entirely.
- Low and predictable Claude API cost, suitable for personal daily use.

## Out of scope for v1

- No multi-user support or sharing of reminders.
- No cross-platform support; iOS only for v1.
- No calendar or email integration in v1.
- No complex project or sub-task management; this is a reminder and
  nudge system, not a project management tool.

## Screens and user flows

### Siri capture (hands-free)
User triggers the app intent by voice, speaks the reminder, it is
transcribed on-device and stored immediately as raw text with a
timestamp. No questions are asked back; Siri cannot easily hand control
back to the app mid-conversation, so this path optimizes purely for
frictionless capture.

### In-app capture (conversational)
User opens the app and either types or speaks a reminder. Claude asks one
or two follow-up questions inline (deadline, importance) if the item
seems to warrant it, and the reminder is stored already structured,
skipping nightly review.

### Nightly review
Once a day Claude reviews all undated or unstructured items captured
since the last review (mainly from Siri) and either auto-assigns a
bucket and deadline where confident, or raises a short list of items for
the user to quickly confirm or adjust the following morning or evening,
whichever check-in time is set. Accepting Claude's suggestion is a single
tap.

### Long-horizon escalation
Items identified as recurring or far out (every six months, annually) get
their own notification schedule: a heads-up at a configurable lead time
(default 15 days before), a second reminder closer in (default 5 days
before), and on the due date a check-in notification asking whether it
was completed. If marked incomplete, it reschedules for the next cycle.

## Data model

Single main entity, `ReminderItem`, stored in SwiftData:

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

## Business rules / domain logic

- Every captured item is timestamped and stored locally immediately,
  before any Claude classification call, so nothing is lost if the
  network or API call fails.
- Classification runs asynchronously after capture; the user never waits
  on it during capture.
- Low-confidence classifications are flagged for the nightly review
  instead of being silently assumed.
- Items captured via in-app conversational mode are marked as already
  structured and excluded from nightly review.
- Short-horizon items (quick task, scheduled task) get a single
  notification at or near the deadline — no escalation sequence.
- Long-horizon items get a three-stage notification sequence per cycle:
  lead-time nudge (default 15 days before), second nudge (default 5 days
  before), due-date check-in with quick actions (Done / Not yet). If
  marked "Not yet," the item reschedules forward by its recurring
  interval and the sequence restarts. Lead times are user-configurable,
  not hardcoded.
- Nightly review notification fires once daily at a user-set time only
  if there are undated or low-confidence items awaiting review — no
  notification if the queue is empty, to avoid notification fatigue.
- Notification copy is generated once at classification time and stored,
  not regenerated live, to avoid unnecessary API calls.
- All notifications are local (UNUserNotificationCenter); no push server
  dependency in v1.
- The Anthropic API key is stored in the iOS Keychain, never in
  plaintext or in SwiftData.

## Claude API integration

- **Model choice:** Claude Haiku for per-item classification (bucket,
  urgency, deadline parsing) and the nightly digest — structured
  extraction, not deep reasoning. In-app conversational follow-up
  questions may use a mid-tier model if responses feel too rigid;
  validate empirically rather than assuming.
- **Request pattern:** one API call per capture, transcribed text + system
  prompt instructing Claude to return strict JSON: bucket, urgency,
  extracted deadline (or null), recurring interval, confidence score.
- **Example JSON contract:**
  ```json
  {
    "bucket": "quick_task | scheduled_task | long_horizon",
    "urgency": "low | medium | high",
    "deadline": "2026-10-20 or null",
    "recurring_interval": "none | monthly | six_month | annual | custom",
    "confidence": 0.0
  }
  ```
- **Nightly digest call:** one call per day aggregates all open
  low-confidence items and proposes a bucket, deadline, and priority for
  each; user accepts or adjusts with a single tap.
- Estimated monthly cost well under $1 even at heavy use (~20 captures/day
  plus one nightly digest call). Check current Anthropic pricing before
  finalizing.

## Technical stack

- Swift / SwiftUI (same stack as SpotSyk for consistency)
- SwiftData for local offline-first storage
- App Intents for the Siri entry point
- Apple's Speech framework for on-device transcription
- UNUserNotificationCenter for all reminders
- URLSession over HTTPS for the Claude API call — the only network
  dependency; everything else works fully offline.

## UX principles (friction-reduction)

- Capture must never ask a question. The Siri path logs raw text and
  nothing else.
- Siri trigger must work with the phone locked and in a pocket.
- Nightly review must be fast, not thorough — one-tap accept is the
  default interaction.
- Notifications must be sparse and meaningful — no notification unless
  there's something genuinely to review or act on.
- Long-horizon items must stay out of daily view entirely until their
  lead-time nudge fires.
- Before building out further, validate the single moment that matters:
  the two seconds after invoking Siri.

## Phased build plan

- **Phase 0 — Validate the core moment.** Siri App Intent + raw
  capture-to-storage path only. No classification, no UI polish. Use for
  real for a week or two; confirm the hands-free trigger is fast and
  reliable.
- **Phase 1 — Classification and nightly review.** Claude API integration
  for bucket/urgency/deadline classification, plus the nightly review
  flow for undated items.
- **Phase 2 — In-app conversational capture.** Richer in-app flow where
  Claude asks clarifying questions live, bypassing nightly review.
- **Phase 3 — Long-horizon escalation workflow.** Recurring interval
  tagging and the three-stage lead-time notification sequence with
  completion check-ins.
- **Phase 4 — Polish and refinement.** Visual design, settings for
  configurable lead times and review time, based on real usage from
  earlier phases.

## Open questions and risks

- Can a Siri App Intent reliably capture and transcribe speech without
  the user unlocking the phone, across lock-screen and CarPlay scenarios?
  Needs hands-on testing early.
- Should low-confidence or ambiguous transcriptions be confirmed back to
  the user via sound/haptic, or silently queued for nightly review?
- What happens if the Claude API call fails or times out — silent retry,
  or a visible "needs classification" fallback state in-app?
- How much flexibility is needed in recurring intervals beyond six-month
  and annual (e.g. quarterly, custom day counts)?
- Is a single Anthropic API key per user sufficient for v1, or should
  there be a rate-limiting/cost safeguard in the app itself?
- Primary risk: abandonment due to friction, as happened with SpotSyk —
  mitigated by the Phase 0 validation step and the UX principles above,
  but worth revisiting honestly after two weeks of real use.
