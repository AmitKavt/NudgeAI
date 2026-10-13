---
owned_by: documenter
updated_by: planner (adds tasks), documenter (marks complete)
---

# TASKS.md — Nudge AI Build Checklist

## Phase 0: Project Scaffolding — ✅ complete
Done criteria: project builds with zero errors, no feature code.

- [x] Create Xcode project (SwiftUI app, iOS 17+ deployment target)  [status: done]  [agent: implementer]
- [x] Create empty module folders per CLAUDE.md structure (App, Onboarding, Capture, Classification, Review, Reminders, Notifications, Persistence, Settings, Profile, Tests)  [status: done]  [agent: implementer]
- [x] Add empty SwiftData model container boilerplate in Persistence  [status: done]  [agent: implementer]
- [x] Confirm project builds with zero errors on simulator  [status: done]  [agent: implementer]

## Phase 1: Validate the Core Moment (Siri Capture)
Done criteria: Siri App Intent captures speech and writes a ReminderItem with zero required input, works with phone locked.

- [ ] Define `ReminderItem` SwiftData model per data model in SPEC.md  [status: todo]  [agent: implementer]
- [ ] Implement custom Siri App Intent that opens a capture session without unlocking  [status: todo]  [agent: implementer]
- [ ] Integrate Apple Speech framework for on-device transcription  [status: todo]  [agent: implementer]
- [ ] Write captured item (rawText, createdAt, source=siri) to SwiftData immediately, before any network call  [status: todo]  [agent: implementer]
- [ ] Manually validate lock-screen and lock-in-pocket capture reliability  [status: todo]  [agent: implementer]

## Phase 2: Classification and Nightly Review
Done criteria: every captured item gets classified via Claude API; low-confidence items appear in a working swipeable nightly review flow; Claude-unreachable state works end-to-end.

- [ ] Implement Keychain-backed API key storage in Settings  [status: todo]  [agent: implementer]
- [ ] Build Claude API client (model-selectable: Haiku default, Sonnet opt-in) with strict JSON system prompt per contract in SPEC.md  [status: todo]  [agent: implementer]
- [ ] Wire async classification call after capture, update ReminderItem on response  [status: todo]  [agent: implementer]
- [ ] Implement confidence threshold routing to nightly review  [status: todo]  [agent: implementer]
- [ ] Build nightly digest Claude API call (aggregates low-confidence items)  [status: todo]  [agent: implementer]
- [ ] Build swipeable nightly review card stack UI (swipe right = accept, left = skip), showing type/urgency/deadline/confidence  [status: todo]  [agent: implementer]
- [ ] Schedule nightly review notification only when queue is non-empty, at user-configured time (default 9 PM)  [status: todo]  [agent: implementer]
- [ ] Implement Claude-unreachable detection, Today screen banner, and "paused" review state with automatic resume on reconnect  [status: todo]  [agent: implementer]

## Phase 3: In-App Conversational Capture
Done criteria: in-app flow asks up to two quick-reply follow-up questions and produces an already-structured item, excluded from nightly review.

- [ ] Build in-app capture UI (text + voice input, modal sheet)  [status: todo]  [agent: implementer]
- [ ] Implement conversational follow-up question flow with quick-reply chips (e.g. "This week"/"This month"/"Every 6 months"/"No deadline")  [status: todo]  [agent: implementer]
- [ ] Resolve quick-reply chip taps to concrete deadline/recurring_interval client-side (no second API round-trip)  [status: todo]  [agent: implementer]
- [ ] Mark in-app captured items `isPreStructured = true`, excluded from nightly review query  [status: todo]  [agent: implementer]
- [ ] Build post-capture confirmation card showing computed schedule  [status: todo]  [agent: implementer]

## Phase 4: Long-Horizon Escalation Workflow
Done criteria: long-horizon items run the full three-stage notification sequence, reschedule correctly on incompletion, and are browsable via the Long-horizon tab and Reminder detail screen with history.

- [ ] Implement recurring interval tagging (sixMonth, annual, custom)  [status: todo]  [agent: implementer]
- [ ] Implement three-stage notification scheduling (lead nudge, second nudge, due-date check-in) honoring quiet hours  [status: todo]  [agent: implementer]
- [ ] Implement due-date check-in quick actions (Done / Not yet) as actionable notifications, with a Settings toggle to disable the check-in entirely  [status: todo]  [agent: implementer]
- [ ] Implement reschedule-on-incomplete logic, recomputing nextNudgeAt; implement lastCompletedAt update on "Done"  [status: todo]  [agent: implementer]
- [ ] Build Long-horizon tab UI: "Nudging soon" and "Later" sections  [status: todo]  [agent: implementer]
- [ ] Build Reminder detail screen: nudge schedule, stage descriptions, completion history  [status: todo]  [agent: implementer]
- [ ] Add TabBar navigation (Today / Long-horizon / You)  [status: todo]  [agent: implementer]

## Phase 5: Onboarding, Settings, and Profile
Done criteria: onboarding, full Settings (all four groups + sub-screens), and Profile/stats screen are implemented and wired to real data.

- [ ] Build onboarding flow: Welcome, Connect Claude (API key entry), Teach Siri your phrase (with 3-step explainer), Permissions  [status: todo]  [agent: implementer]
- [ ] Build Settings screen with groups: Capture, Review, Nudges, Claude and Data  [status: todo]  [agent: implementer]
- [ ] Build Review and nudge timing sub-screen: review time presets + custom, lead-time steppers with live date preview, due-date check-in toggle, quiet hours  [status: todo]  [agent: implementer]
- [ ] Build Claude and privacy sub-screen: connection status, model picker (Haiku/Sonnet with cost copy), monthly spend alert slider, data/privacy explainer  [status: todo]  [agent: implementer]
- [ ] Build Capture settings sub-screen: Siri phrase display, haptic/spoken confirmation toggles, language setting, ambiguous-transcription policy ("Save it and flag it" vs "Don't save")  [status: todo]  [agent: implementer]
- [ ] Build Profile ("You") screen: stats (captured count, one-tap-review rate, avg capture time), Claude usage/spend this month, links to Settings/Siri phrase/Help  [status: todo]  [agent: implementer]
- [ ] Implement local monthly spend estimate tracking (requests x model pricing) feeding Profile and the spend alert  [status: todo]  [agent: implementer]

## Phase 6: Polish and Refinement
Done criteria: visual polish applied; spend-estimate accuracy validated against real usage.

- [ ] Apply visual design per design.md tokens across all screens  [status: todo]  [agent: implementer]
- [ ] Validate local spend estimate against actual Anthropic billing; tune if drifting  [status: todo]  [agent: implementer]
- [ ] Review real usage patterns from earlier phases and refine friction points  [status: todo]  [agent: implementer]
