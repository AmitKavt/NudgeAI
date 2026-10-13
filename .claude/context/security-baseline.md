---
loaded_by: implementer, security-reviewer
unlocks: correct handling of the Anthropic API key and any sensitive data
update_trigger: auth/secrets handling changes, or a new sensitive data type is introduced
owned_by: documenter
---

# Security Baseline

## Scope

Nudge AI is single-user and personal — there is no auth system, no user
accounts, no multi-tenant data. The only sensitive secret in this app is
the user's Anthropic API key.

## Rules

- The Anthropic API key is stored only in the iOS Keychain (via
  `kSecClassGenericPassword` or equivalent) — never in `UserDefaults`,
  SwiftData, plaintext files, or source code.
- The API key is read from Keychain only by the Classification module at
  request time; it is never passed through Notifications, Persistence, or
  logged in any form (including crash reports / error descriptions).
- All Claude API requests go directly from the app to the Anthropic API
  over HTTPS via URLSession — no intermediary server in v1, so there is no
  additional server-side attack surface to review.
- `rawText` (the user's captured reminders) is sent only to the Claude API
  as part of classification — never to any other third party, analytics
  service, or logging backend.
- No plaintext secrets anywhere in source, including test fixtures — use
  placeholder/mock keys in tests.

## Onboarding and API key replacement

- The Onboarding "Connect Claude" step and the Settings "API key"
  replace flow are the only two entry points that write to the Keychain,
  and both do so through the same Settings-owned interface — Onboarding
  does not implement its own Keychain write path.
- Validating a newly entered key (e.g. a lightweight test call) must not
  log the key or the raw response in any form.

## Model picker and spend alert are not security-sensitive

- The Claude Haiku/Sonnet model picker and the monthly spend alert
  threshold are cost/UX settings, not secrets — they do not require
  security-reviewer sign-off on their own. They only trigger a pass if
  their implementation touches the API key handling path itself.

## What triggers a security-reviewer pass

- Any change to Settings or Onboarding's API key entry/storage/replace
  flow
- Any change to the Classification module's request construction or
  response handling
- Any change to how `rawText` flows through the app
