---
owned_by: documenter
updated_by: planner (adds tasks), documenter (marks complete)
---

# TASKS.md — Nudge AI Build Checklist

## Phase 0: Project Scaffolding
Done criteria: project builds with zero errors, no feature code.

- [ ] Create Xcode project (SwiftUI app, iOS 17+ deployment target)  [status: todo]  [agent: implementer]
- [ ] Create empty module folders per CLAUDE.md structure (App, Capture, Classification, Review, Reminders, Notifications, Persistence, Settings, Tests)  [status: todo]  [agent: implementer]
- [ ] Add empty SwiftData model container boilerplate in Persistence  [status: todo]  [agent: implementer]
- [ ] Confirm project builds with zero errors on simulator  [status: todo]  [agent: implementer]

## Phase 1: Validate the Core Moment (Siri Capture)
Done criteria: Siri App Intent captures speech and writes a ReminderItem with zero required input, works with phone locked.

- [ ] Define `ReminderItem` SwiftData model per data model in SPEC.md  [status: todo]  [agent: implementer]
- [ ] Implement custom Siri App Intent that opens a capture session without unlocking  [status: todo]  [agent: implementer]
- [ ] Integrate Apple Speech framework for on-device transcription  [status: todo]  [agent: implementer]
- [ ] Write captured item (rawText, createdAt, source=siri) to SwiftData immediately, before any network call  [status: todo]  [agent: implementer]
- [ ] Manually validate lock-screen and lock-in-pocket capture reliability  [status: todo]  [agent: implementer]

## Phase 2: Classification and Nightly Review
Done criteria: every captured item gets classified via Claude API; low-confidence items appear in a working nightly review flow with one-tap accept.

- [ ] Implement Keychain-backed API key storage in Settings  [status: todo]  [agent: implementer]
- [ ] Build Claude API client (Haiku) with strict JSON system prompt per contract in SPEC.md  [status: todo]  [agent: implementer]
- [ ] Wire async classification call after capture, update ReminderItem on response  [status: todo]  [agent: implementer]
- [ ] Implement confidence threshold routing to nightly review  [status: todo]  [agent: implementer]
- [ ] Build nightly digest Claude API call (aggregates low-confidence items)  [status: todo]  [agent: implementer]
- [ ] Build nightly review UI with one-tap accept/adjust  [status: todo]  [agent: implementer]
- [ ] Schedule nightly review notification only when queue is non-empty  [status: todo]  [agent: implementer]

## Phase 3: In-App Conversational Capture
Done criteria: in-app flow asks up to two follow-up questions and produces an already-structured item, excluded from nightly review.

- [ ] Build in-app capture UI (text + voice input)  [status: todo]  [agent: implementer]
- [ ] Implement conversational follow-up question flow (deadline, importance) via Claude  [status: todo]  [agent: implementer]
- [ ] Mark in-app captured items as pre-structured, excluded from nightly review query  [status: todo]  [agent: implementer]

## Phase 4: Long-Horizon Escalation Workflow
Done criteria: long-horizon items run the full three-stage notification sequence and reschedule correctly on incompletion.

- [ ] Implement recurring interval tagging (sixMonth, annual, custom)  [status: todo]  [agent: implementer]
- [ ] Implement three-stage notification scheduling (lead nudge, second nudge, due-date check-in)  [status: todo]  [agent: implementer]
- [ ] Implement due-date check-in quick actions (Done / Not yet)  [status: todo]  [agent: implementer]
- [ ] Implement reschedule-on-incomplete logic, recomputing nextNudgeAt  [status: todo]  [agent: implementer]

## Phase 5: Polish and Refinement
Done criteria: configurable lead times and review time exposed in Settings; visual polish applied.

- [ ] Build Settings screen: configurable lead times (default 15/5 days), nightly review time  [status: todo]  [agent: implementer]
- [ ] Apply visual design per design.md tokens  [status: todo]  [agent: implementer]
- [ ] Review real usage patterns from earlier phases and refine friction points  [status: todo]  [agent: implementer]
