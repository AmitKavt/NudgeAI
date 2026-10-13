# Nudge AI — Product Spec

> This is the file you (Amit) edit directly. Whenever the product changes,
> update this file, then run the documenter to cascade changes into SPEC.md
> and TASKS.md.
>
> Last synced against the Figma design file (16 screens,
> https://www.figma.com/design/oB82tlQm7eyDgsMdIuHKjx) on 2026-10-13. All
> screens in that file are in scope for v1.

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

## Naming

- App name: **Nudge** (shown in-app, in the TabBar, Settings, Profile).
- **"Nudge AI"** is used as the notification sender/app-icon name shown in
  the iOS notification center, and as the project/repo name.
- A captured item's user-facing noun is a **"nudge"** (e.g. "3 nudges to
  sort," "Tap to speak or type a nudge"). The underlying SwiftData model
  keeps the type name `ReminderItem` for code clarity — that's an
  internal/engineering name only and never appears in UI copy.

## Persona

Just Amit — single user, personal daily-use tool. No multi-user design
needed for v1.

## Goals

- Zero-judgment capture: logging a nudge never requires choosing a
  category, priority, or deadline at the moment of capture.
- Hands-free capture via a custom Siri phrase, usable without unlocking
  or opening the phone.
- Claude-driven classification into buckets and urgency tiers, run
  asynchronously after capture.
- A nightly review flow inside the app for short-horizon, undated items
  that need a deadline or priority decision.
- A separate escalating notification workflow for long-horizon reminders
  (recurring annually, every six months, etc.), with reminders at
  configurable lead times (default 15 days and 5 days out) and a
  completion check-in.
- An in-app conversational capture mode where Claude asks clarifying
  questions live, so those items skip nightly triage entirely.
- Low and predictable Claude API cost, suitable for personal daily use,
  with a visible spend alert so cost is never a surprise.
- A guided onboarding that gets Siri capture working in under three
  steps, since the hands-free moment is the app's core value prop.
- Graceful, honest behavior when Claude is unreachable — never lose a
  captured nudge, never pretend review happened when it didn't.

## Out of scope for v1

- No multi-user support or sharing of reminders.
- No cross-platform support; iOS only for v1.
- No calendar or email integration in v1.
- No complex project or sub-task management; this is a reminder and
  nudge system, not a project management tool.
- No server-side account system — the app talks directly to the Claude
  API with the user's own key; there is no Nudge backend.

## Information architecture

A persistent tab bar provides navigation across the app's three main
areas, plus a modal capture sheet reachable from any tab:

- **Today** — the daily view: tonight's review summary, items captured
  today, and a note about resting long-horizon reminders.
- **Long-horizon** — the dedicated home for recurring/far-out reminders,
  split into "Nudging soon" (inside their lead-time window) and "Later"
  (not yet due for a nudge).
- **You** — profile and stats (capture count, one-tap-review rate,
  average capture time, Claude usage/spend this month), plus entry
  points to Settings, the Siri phrase, and Help and feedback.
- **Capture** (modal, not a tab) — reachable via the mic/input bar on
  Today, or the Siri phrase from anywhere, including locked.

## Screens and user flows

### Onboarding (first launch only)
A three-step guided setup, each step showing progress ("1 of 3," etc.):

1. **Welcome** — "Capture anything in two seconds. No categories, no
   deadlines, no decisions. Say it now. Claude sorts it out tonight."
   Reassures that notes and the API key stay on-device.
2. **Connect Claude** — user enters their own Anthropic API key in-app.
   Copy: "Nudge uses your own Anthropic API key to sort what you
   capture. It lives in the iPhone Keychain." Includes a "Private by
   design" note: calls go straight from the phone to Claude, no
   intermediary server, typical cost well under $1/month on Haiku.
3. **Teach Siri your phrase** — walks through the default phrase ("Hey
   Siri, nudge me"), explains it works phone-locked/pocketed/in the car,
   and shows a 3-step "how it works" explainer: (1) say your thought, no
   questions asked; (2) keep going with your day, capture finishes in
   ~2 seconds; (3) tonight, Claude sorts it, you approve in one tap.
4. **Permissions** — requests Microphone, Speech Recognition, and
   Notifications, each with a one-line plain-language reason ("Hear you
   when you say your phrase," "Turn your voice into text on this
   device," "Nightly review and long-horizon nudges").

### Siri capture (hands-free)
User triggers the app intent by voice, speaks the reminder, it is
transcribed on-device and stored immediately as raw text with a
timestamp. No questions are asked back; Siri cannot easily hand control
back to the app mid-conversation, so this path optimizes purely for
frictionless capture. Confirmation back to the user ("Saved. I'll sort
it tonight.") is itself configurable — see Capture settings below.

### In-app capture (conversational)
User opens the app (or taps the capture bar on Today) and either types
or speaks a nudge. Claude asks up to one or two follow-up questions
inline, presented as tappable quick-reply chips rather than open text —
for example, after "Dentist checkup," Claude asks "When does this need
to happen? A rough answer is fine," with quick replies like "This
week," "This month," "Every 6 months." Once answered, the nudge is
stored already structured (bucket, deadline/recurring interval derived
from the reply) and a confirmation card shows the computed schedule
(e.g. "Saved as long-horizon · Every 6 months · next due 2 Dec"). Items
captured this way skip nightly review entirely.

### Nightly review
Once a day, at a user-configured time (default 9:00 PM), Claude reviews
all undated or low-confidence items captured since the last review
(mainly from Siri) and surfaces them one at a time in a swipeable card
stack ("1 of 3," etc.). Each card shows what was said, who/when it was
captured, and Claude's suggestion: bucket, urgency, deadline, and a
confidence percentage. **Swipe right to accept, swipe left to skip** —
this is the one-tap-equivalent interaction, not a list of buttons. The
review notification only fires if the queue is non-empty.

### Long-horizon escalation
Items identified as recurring or far out (every six months, annually, or
custom) get their own notification schedule, visible end-to-end in the
**Long-horizon** tab and a **Reminder detail** screen per item:
a heads-up at a configurable lead time (default 15 days before, shown as
"A gentle heads-up"), a second reminder closer in (default 5 days
before, "A firmer reminder"), and on the due date a check-in
notification ("Did you get it done? If not, I'll move it to the next
cycle.") with quick actions **Done** / **Not yet** actionable directly
from the notification. If marked "Not yet," the item reschedules for
the next cycle automatically. The Reminder detail screen also shows
completion history (e.g. "Last completed 2 June. Next cycle was
scheduled automatically.").

### Claude-unreachable state
If the Claude API can't be reached, the Today screen shows an explicit
banner: "Can't reach Claude. Your nudges are safe. I'll sort them when
you're back online." The nightly review section shows "Paused until
Claude is reachable" instead of attempting a silent retry or guessing.
Capture is entirely unaffected — items are always written locally first,
regardless of connectivity.

### Settings
Organized into four groups:

- **Capture** — Siri phrase (view/re-teach), "Confirm with a haptic"
  toggle; a dedicated Capture settings sub-screen adds "Say 'Saved' out
  loud" toggle, Language (e.g. "English (India)"), and the ambiguous-
  transcription policy: **"Save it and flag it"** (default — keeps the
  raw words and asks at tonight's review) vs. **"Don't save"** (discard
  anything below the confidence threshold).
- **Review** — nightly review time (preset chips: 8 PM / 9 PM / 10 PM /
  Custom, default 9 PM), "Skip when nothing to sort" toggle (always on
  in practice — no notification fires on an empty queue).
- **Nudges** — long-horizon lead times (default 15 and 5 days, adjustable
  via steppers, with a live preview of computed dates for an example due
  date), a due-date check-in on/off toggle, and Quiet hours ("Hold
  nudges overnight," default 10 PM–7 AM) which delays non-urgent nudge
  delivery until the window ends.
- **Claude and data** — API key (re-enter/replace), Model picker
  (**Claude Haiku**, default — "Fast and cheap. Great at sorting what
  you capture." vs. **Claude Sonnet** — "Better follow-up questions in
  the app. Costs more."), Monthly spend alert (slider, default $5 — "a
  warning, never a surprise bill"), and a "Data and privacy" explainer:
  "Only the text of a nudge, sent straight to Claude. No Nudge server,
  no account."

### Profile ("You")
Shows: name/avatar, "Nudging since [month/year]," and three stats —
total captured count, one-tap-review rate (% of reviews accepted
without adjustment), and average capture time. A "Claude usage this
month" section shows total spend and request count on the current
model. Links out to Settings, Siri phrase, and Help and feedback.

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
| isPreStructured | Bool | true for in-app conversational captures; excludes the item from nightly review |
| lastCompletedAt | Date? | nullable; set when a long-horizon cycle's due-date check-in is marked "Done" |
| transcriptionConfidence | Double? | nullable; on-device speech confidence, used only when the "don't save below threshold" policy is active |

Plus a lightweight `AppSettings` entity (or a small set of UserDefaults /
Keychain-backed values — see data-conventions.md) holding: Siri phrase
text, haptic/spoken-confirmation toggles, nightly review time, "when
unsure" policy, lead times, due-date check-in enabled, quiet hours
window, selected Claude model, monthly spend alert threshold, and
language. These are configuration, not reminder data, and must never be
synced anywhere beyond local storage.

## Business rules / domain logic

- Every captured item is timestamped and stored locally immediately,
  before any Claude classification call, so nothing is lost if the
  network or API call fails.
- Classification runs asynchronously after capture; the user never waits
  on it during capture.
- Low-confidence classifications are flagged for the nightly review
  instead of being silently assumed.
- Items captured via in-app conversational mode are marked
  `isPreStructured = true` and excluded from nightly review.
- Short-horizon items (quick task, scheduled task) get a single
  notification at or near the deadline — no escalation sequence.
- Long-horizon items get a three-stage notification sequence per cycle:
  lead-time nudge (default 15 days before), second nudge (default 5 days
  before), due-date check-in with quick actions (Done / Not yet) — the
  due-date check-in itself can be disabled in Settings, in which case the
  item simply isn't prompted for completion and does not auto-reschedule.
  If marked "Not yet," the item reschedules forward by its recurring
  interval, the sequence restarts, and `lastCompletedAt` is left
  unchanged; if marked "Done," `lastCompletedAt` is updated and the next
  cycle is scheduled automatically. Lead times are user-configurable, not
  hardcoded.
- Nightly review notification fires once daily at a user-set time only
  if there are undated or low-confidence items awaiting review — no
  notification if the queue is empty, to avoid notification fatigue.
- During configured quiet hours, long-horizon and short-horizon
  notifications are held and delivered at the end of the window rather
  than firing overnight; the nightly review notification's own time
  setting is independent of quiet hours (a user who sets review for
  9 PM inside their own quiet-hours window is explicitly choosing that).
- Notification copy is generated once at classification time and stored,
  not regenerated live, to avoid unnecessary API calls.
- All notifications are local (UNUserNotificationCenter); no push server
  dependency in v1.
- The Anthropic API key is stored in the iOS Keychain, never in
  plaintext or in SwiftData.
- When Claude is unreachable, captured items remain in local storage with
  classification pending; nightly review is explicitly paused (not
  retried silently) and a banner communicates this; as soon as
  connectivity/the API returns, pending items are classified and review
  resumes on its normal schedule.
- The "when I'm not sure what I heard" policy governs only low
  *transcription*-confidence captures (a Speech-framework signal,
  distinct from Claude's classification `confidence`): "Save it and flag
  it" keeps the raw text and routes it to nightly review regardless of
  classification outcome; "Don't save" discards the capture before it
  ever reaches Persistence or Classification.
- The monthly spend alert is advisory only (a local running total
  against the Haiku/Sonnet pricing compared to the user's threshold) —
  it never blocks capture or classification, it only surfaces a warning.

## Claude API integration

- **Model choice:** user-selectable in Settings between **Claude Haiku**
  (default — classification, deadline parsing, nightly digest) and
  **Claude Sonnet** (opt-in, primarily for more natural in-app
  conversational follow-up questions; costs more). The app does not
  silently upgrade models — the user explicitly picks one, and that
  choice applies to all Claude calls (capture classification, nightly
  digest, and in-app follow-ups) unless/until a future version splits
  model choice per call type.
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
- **In-app quick-reply deadlines:** when the in-app flow resolves a
  deadline via a quick-reply chip ("This week," "This month," "Every 6
  months," "No deadline"), the client resolves the relative phrase to a
  concrete `deadline` date (for non-recurring replies) or
  `recurring_interval` (for "Every 6 months"-style replies) itself,
  without a second API round-trip — Claude's role in this flow is
  generating the follow-up question and quick-reply options, not
  re-parsing the user's chip tap.
- **Nightly digest call:** one call per day aggregates all open
  low-confidence items and proposes a bucket, deadline, and priority for
  each; user accepts or adjusts via the swipeable review card stack.
- **Spend tracking:** the client keeps a local running total of the
  current month's estimated spend (requests × model pricing) to drive
  the Profile screen's "Claude usage" figure and the spend-alert
  threshold in Settings; this is an estimate derived from known per-call
  token patterns, not a value read from the Anthropic API.
- Estimated monthly cost well under $1 even at heavy use (~20 captures/day
  plus one nightly digest call) on Haiku; Sonnet costs more and the
  Settings copy says so plainly. Check current Anthropic pricing before
  finalizing exact estimates.

## Technical stack

- Swift / SwiftUI (same stack as SpotSyk for consistency)
- SwiftData for local offline-first storage
- App Intents for the Siri entry point
- Apple's Speech framework for on-device transcription
- UNUserNotificationCenter for all reminders, including actionable
  notifications (Done / Not yet on the due-date check-in)
- URLSession over HTTPS for the Claude API call — the only network
  dependency; everything else works fully offline.

## UX principles (friction-reduction)

- Capture must never ask a question. The Siri path logs raw text and
  nothing else.
- Siri trigger must work with the phone locked and in a pocket.
- Nightly review must be fast, not thorough — a swipe-to-accept card
  stack is the default interaction, not a form to fill out.
- Notifications must be sparse and meaningful — no notification unless
  there's something genuinely to review or act on; quiet hours exist
  specifically to protect this.
- Long-horizon items must stay out of daily view entirely until their
  lead-time nudge fires, and live in their own tab rather than cluttering
  Today even when resting.
- When something goes wrong (Claude unreachable, low-confidence
  transcription), say so plainly and keep the user's data safe — never
  silently drop a nudge, never silently guess without a way to review it.
- Cost should be visible and bounded by a simple alert, not hidden until
  a bill arrives.
- Before building out further, validate the single moment that matters:
  the two seconds after invoking Siri.

## Phased build plan

- **Phase 0 — Validate the core moment.** Siri App Intent + raw
  capture-to-storage path only. No classification, no UI polish. Use for
  real for a week or two; confirm the hands-free trigger is fast and
  reliable.
- **Phase 1 — Classification and nightly review.** Claude API integration
  for bucket/urgency/deadline classification, plus the swipeable nightly
  review flow for undated items, plus the Claude-unreachable banner/
  paused-review state.
- **Phase 2 — In-app conversational capture.** Richer in-app flow where
  Claude asks clarifying questions live via quick-reply chips, bypassing
  nightly review.
- **Phase 3 — Long-horizon escalation workflow.** Recurring interval
  tagging, the Long-horizon tab (Nudging soon / Later), the Reminder
  detail screen with history, and the three-stage lead-time notification
  sequence with completion check-ins.
- **Phase 4 — Onboarding, Settings, and Profile.** The three-step
  onboarding flow (Welcome, Connect Claude, Teach Siri, Permissions), the
  full Settings screen (Capture, Review, Nudges, Claude and Data groups)
  and its sub-screens (Review and nudge timing, Claude and privacy,
  Capture settings), and the Profile/"You" screen with stats and Claude
  usage.
- **Phase 5 — Polish and refinement.** Visual design pass, spend-alert
  accuracy tuning, based on real usage from earlier phases.

## Open questions and risks

- Can a Siri App Intent reliably capture and transcribe speech without
  the user unlocking the phone, across lock-screen and CarPlay scenarios?
  Needs hands-on testing early.
- The local spend estimate (requests × known pricing) could drift from
  actual Anthropic billing over time — worth a periodic sanity check
  against the real invoice rather than treating the in-app figure as
  authoritative.
- Quiet hours interacting with the nightly review time: if a user sets
  both to overlap, is that just allowed as-is (current assumption), or
  should the UI warn them their review notification will arrive during
  quiet hours?
- How much flexibility is needed in recurring intervals beyond six-month
  and annual (e.g. quarterly, custom day counts)? The Settings/stepper UI
  suggests day-granularity lead times already; custom recurring
  intervals beyond the enum aren't yet designed.
- Primary risk: abandonment due to friction, as happened with SpotSyk —
  mitigated by the Phase 0 validation step and the UX principles above,
  but worth revisiting honestly after two weeks of real use.
