---
loaded_by: implementer, security-reviewer
unlocks: correct handling of the Anthropic API key and any sensitive data
update_trigger: auth/secrets handling changes, or a new sensitive data type is introduced
owned_by: documenter
---

# Security Baseline

## Scope

Nudge AI is single-user and personal — there is no auth system, no user
accounts, no multi-tenant data. The sensitive secrets are the user's LLM
platform API keys (one per platform) and the Apple user identifier
(Sign in with Apple, local identity only, no server).

## Rules

- Each platform's API key and the Apple user identifier are stored only
  in the iOS Keychain (via
  `kSecClassGenericPassword` or equivalent) — never in `UserDefaults`,
  SwiftData, plaintext files, or source code.
- Disconnecting a platform deletes its key. A key is read from Keychain
  only by the Classification module (client factory) at
  request time; it is never passed through Notifications, Persistence, or
  logged in any form (including crash reports / error descriptions).
- All LLM requests go directly from the app to the chosen platform's API
  (Anthropic or DeepSeek) over HTTPS via URLSession — no intermediary server in v1, so there is no
  additional server-side attack surface to review.
- `rawText` (the user's captured reminders) is sent only to the connected provider's
  API as part of classification — never to any other third party, analytics
  service, or logging backend.
- No plaintext secrets anywhere in source, including test fixtures — use
  placeholder/mock keys in tests.

## Onboarding and API key replacement

- The Onboarding AI-platform step, the Settings "API key"
  replace flow, and the Sign in with Apple identifier save are the only
  entry points that write to the Keychain,
  and both do so through the same Settings-owned interface — Onboarding
  does not implement its own Keychain write path.
- Validating a newly entered key (e.g. a lightweight test call) must not
  log the key or the raw response in any form.

## Model picker and spend alert are not security-sensitive

- The model picker and the monthly spend alert
  threshold are cost/UX settings, not secrets — they do not require
  security-reviewer sign-off on their own. They only trigger a pass if
  their implementation touches the API key handling path itself.

## What triggers a security-reviewer pass

- Any change to Settings or Onboarding's API key entry/storage/replace/
  disconnect flow, provider selection, or Sign in with Apple handling
  (always required for Phase 7)
- Any change to the Classification module's request construction or
  response handling
- Any change to how `rawText` flows through the app
