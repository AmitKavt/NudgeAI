# CLAUDE.md

> You (the developer) should only ever edit two files directly:
> 1. `References/NudgeAI_Spec.md` — what the app does
> 2. `CLAUDE.md` — how Claude builds it
>
> After editing either file, run the documenter to cascade changes.

## Project

**Nudge AI** — a native iOS app that removes the friction between having a
thought worth remembering and actually capturing it, by separating capture
(zero-structure, hands-free via Siri or in-app) from classification (Claude
API assigns bucket, urgency, and deadline afterward, asynchronously).

## How to start work

For any new feature, bug fix, or phase:
1. Invoke `.claude/agents/planner.md`
2. The planner loads its own context and hands off automatically
3. Do not invoke any other agent directly unless resuming a broken pipeline

Pipeline:
planner → implementer → test-engineer + security-reviewer* → code-reviewer → documenter
*security-reviewer only if auth / secrets / sensitive data is touched

## Design Reference

- Figma file (16 screens, source of truth for all UI): https://www.figma.com/design/oB82tlQm7eyDgsMdIuHKjx/Nudge-AI-%E2%80%94-iOS-Designs
- Screen → Figma node-id map: `References/Mockups/README.md`

## Tech Stack

- **Language:** Swift
- **UI framework:** SwiftUI
- **Persistence:** SwiftData (offline-first)
- **Auth/secrets:** iOS Keychain for the Anthropic API key — no auth system otherwise (single-user, personal app)
- **Speech:** Apple's Speech framework (on-device transcription)
- **Voice entry point:** App Intents (custom Siri phrase)
- **Notifications:** UNUserNotificationCenter (local only, no push server)
- **Network:** URLSession over HTTPS — Claude API is the only network dependency
- **Deployment target:** iOS 17+
- **Third-party dependencies:** none without explicit approval

## Module / Folder Structure

```
NudgeAI/
├── App/                     — app entry point, App Intents (Siri) registration, TabBar host
├── Onboarding/              — Welcome, Connect Claude, Teach Siri, Permissions (first-launch wizard)
├── Capture/                 — Siri capture intent, in-app capture UI, speech-to-text, confirmation feedback
├── Classification/          — Claude API client, prompt templates, JSON contract parsing, unreachable-state tracking
├── Review/                  — nightly review flow and swipeable card-stack UI
├── Reminders/               — long-horizon escalation scheduling logic, Long-horizon tab, Reminder detail screen
├── Notifications/           — UNUserNotificationCenter scheduling, quiet hours, copy generation
├── Persistence/             — SwiftData models (ReminderItem, AppSettings) and repositories
├── Settings/                — API key entry (Keychain), capture/review/nudge/model config, spend alert
├── Profile/                 — stats screen (capture count, review rate, avg capture time, Claude usage)
└── Tests/                   — unit tests, no UI/framework imports in core logic tests
```

## Build Order

1. Phase 0 — Project scaffolding (builds, zero feature code)
2. Phase 1 — Validate the core moment: Siri App Intent + raw capture-to-storage path only
3. Phase 2 — Classification and nightly review (Claude API integration, Claude-unreachable state)
4. Phase 3 — In-app conversational capture (quick-reply follow-ups)
5. Phase 4 — Long-horizon escalation workflow (tab, detail screen, history)
6. Phase 5 — Onboarding, Settings, and Profile
7. Phase 6 — Polish and refinement (visual design, spend-estimate accuracy)

## Non-Negotiable Rules

- No third-party dependencies without explicit approval.
- Capture must never ask a question or require a decision at capture time — the Siri path logs raw text and nothing else.
- Every captured item is timestamped and stored locally immediately, before any Claude classification call.
- All notifications are local (UNUserNotificationCenter); no push server dependency.
- The Anthropic API key is stored in the iOS Keychain — never in plaintext or in SwiftData.
- Classification runs asynchronously after capture; the user never waits on it during capture.
- Low-confidence classifications are flagged for nightly review, never silently assumed.
- No notification fires if there is nothing to review — avoid notification fatigue.
- Core logic (classification parsing, scheduling rules) must be unit-testable with zero UI/framework imports.
- Do not implement anything in SPEC.md out-of-scope section.
- Nudge AI has no backend/server/account system — the app talks directly to the user's own Anthropic API key over HTTPS.
- When Claude is unreachable, never lose a captured nudge and never silently retry review — surface it plainly (Today banner, paused review) and resume automatically once reachable.
- Settings-driven behavior (quiet hours, lead times, model choice, ambiguous-transcription policy, spend alert) must be read live from `AppSettings`, never hardcoded, since the design treats all of these as user-configurable from day one.
