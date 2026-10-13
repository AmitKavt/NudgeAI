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
├── App/                     — app entry point, App Intents (Siri) registration
├── Capture/                 — Siri capture intent, in-app capture UI, speech-to-text
├── Classification/          — Claude API client, prompt templates, JSON contract parsing
├── Review/                  — nightly review flow and UI
├── Reminders/               — long-horizon escalation scheduling logic
├── Notifications/           — UNUserNotificationCenter scheduling and copy generation
├── Persistence/             — SwiftData models (ReminderItem) and repositories
├── Settings/                — API key entry (Keychain), lead-time config, review time config
└── Tests/                   — unit tests, no UI/framework imports in core logic tests
```

## Build Order

1. Phase 0 — Project scaffolding (builds, zero feature code)
2. Phase 1 — Validate the core moment: Siri App Intent + raw capture-to-storage path only
3. Phase 2 — Classification and nightly review (Claude API integration)
4. Phase 3 — In-app conversational capture
5. Phase 4 — Long-horizon escalation workflow
6. Phase 5 — Polish and refinement (visual design, configurable settings)

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
