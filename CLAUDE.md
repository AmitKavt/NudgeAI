# CLAUDE.md

> You (the developer) should only ever edit two files directly:
> 1. `References/NudgeAI_Spec.md` — what the app does
> 2. `CLAUDE.md` — how Claude builds it
>
> After editing either file, run the documenter to cascade changes.

## Project

**Nudge AI** — a native iOS app that removes the friction between having a
thought worth remembering and actually capturing it, by separating capture
(zero-structure, hands-free via Siri or in-app) from classification (a
user-chosen LLM provider, DeepSeek or Anthropic, assigns bucket, urgency,
and deadline afterward, asynchronously; with no provider connected the
user sorts items manually at review).

## How to start work

For any new feature, bug fix, or phase:
1. Invoke `.claude/agents/planner.md`
2. The planner loads its own context and hands off automatically
3. Do not invoke any other agent directly unless resuming a broken pipeline

Pipeline:
planner → implementer → test-engineer + security-reviewer* → code-reviewer → documenter
*security-reviewer only if auth / secrets / sensitive data is touched (always for Phase 7: Keychain keys and Apple identity)

## Design Reference

- Figma file (16 screens, source of truth for all UI): https://www.figma.com/design/oB82tlQm7eyDgsMdIuHKjx/Nudge-AI-%E2%80%94-iOS-Designs
- Screen → Figma node-id map: `References/Mockups/README.md`

## Project Generation

The Xcode project is generated from `project.yml` via [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`). After adding/removing/renaming source files or
targets, regenerate with:

```
xcodegen generate
```

Both `project.yml` and the generated `NudgeAI.xcodeproj` are committed so
the project opens directly in Xcode without requiring XcodeGen — but
`project.yml` is the source of truth; hand-edits to the `.xcodeproj` file
list will be overwritten on the next `xcodegen generate`.

## Tech Stack

- **Language:** Swift
- **UI framework:** SwiftUI
- **Persistence:** SwiftData (offline-first)
- **Auth/secrets:** iOS Keychain holds one API key per LLM platform plus the Apple user identifier. Sign in with Apple (AuthenticationServices) is a local identity only — no auth server, no tokens sent anywhere (single-user, personal app)
- **Speech:** Apple's Speech framework (on-device transcription)
- **Voice entry point:** App Intents (custom Siri phrase)
- **Notifications:** UNUserNotificationCenter (local only, no push server)
- **Network:** URLSession over HTTPS — the user's chosen LLM platform (DeepSeek or Anthropic) is the only network dependency, and it is optional
- **LLM providers:** one provider-neutral protocol with a small URLSession adapter per platform (Anthropic Messages API, DeepSeek OpenAI-compatible chat completions). No provider SDKs
- **Deployment target:** iOS 17+
- **Third-party dependencies:** none without explicit approval

## Module / Folder Structure

```
NudgeAI/
├── App/                     — app entry point, App Intents (Siri) registration, TabBar host
├── Onboarding/              — Welcome, Sign in with Apple, Choose AI platform (with skip), Teach Siri, Permissions (first-launch wizard)
├── Capture/                 — Siri capture intent, in-app capture UI, speech-to-text, confirmation feedback
├── Classification/          — provider-neutral client protocol, per-platform adapters (Anthropic, DeepSeek), client factory (nil when no provider), prompt templates, JSON contract parsing, unreachable-state tracking
├── Review/                  — nightly review flow, swipeable card-stack UI, unsorted cards, Adjust (manual sort) editor
├── Reminders/               — long-horizon escalation scheduling logic, Long-horizon tab, Reminder detail screen
├── Notifications/           — UNUserNotificationCenter scheduling, quiet hours, copy generation
├── Persistence/             — SwiftData models (ReminderItem, AppSettings) and repositories
├── Settings/                — platform picker, per-platform API key entry (Keychain), capture/review/nudge/model config, spend alert
├── Profile/                 — stats screen (capture count, review rate, avg capture time, AI usage), Apple identity / sign out
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
8. Phase 7 — Multi-provider LLM (Anthropic + DeepSeek behind one protocol), no-provider manual sorting with a real Adjust flow, and Sign in with Apple onboarding. This absorbs Phase 6's open "Adjust" task. (In NudgeAI_Spec.md this is "Phase 6", because the spec numbers its phases from 0 to 5.)

## Non-Negotiable Rules

- No third-party dependencies without explicit approval.
- Capture must never ask a question or require a decision at capture time — the Siri path logs raw text and nothing else.
- Every captured item is timestamped and stored locally immediately, before any Claude classification call.
- All notifications are local (UNUserNotificationCenter); no push server dependency.
- Each platform's API key (and the Apple user identifier) is stored in the iOS Keychain — never in plaintext or in SwiftData. Disconnecting a platform deletes its key.
- Classification runs asynchronously after capture; the user never waits on it during capture.
- The app must be fully usable with no LLM provider connected. Capture never depends on a provider, and manual sorting happens at review, never at capture. With no provider the client factory returns nil and callers skip classification; this is not an error and must not show the unreachable banner.
- No provider SDKs. Every platform goes through one protocol with a URLSession adapter; adding a provider must not touch Capture, Review or Settings logic.
- Never hardcode provider-specific names or model IDs outside the adapters and their model lists; UI copy takes the platform name from the selected provider.
- Sign in with Apple is a local identity only; nothing is sent to a Nudge server.
- Low-confidence classifications are flagged for nightly review, never silently assumed.
- No notification fires if there is nothing to review — avoid notification fatigue.
- Core logic (classification parsing, scheduling rules) must be unit-testable with zero UI/framework imports.
- Do not implement anything in SPEC.md out-of-scope section.
- Nudge AI has no backend or server, and no server-side account system — the app talks directly to the chosen platform with the user's own API key over HTTPS. Identity is local via Sign in with Apple.
- When the connected provider is unreachable, never lose a captured nudge and never silently retry review — surface it plainly (Today banner, paused review) and resume automatically once reachable.
- Settings-driven behavior (quiet hours, lead times, model choice, ambiguous-transcription policy, spend alert) must be read live from `AppSettings`, never hardcoded, since the design treats all of these as user-configurable from day one.
