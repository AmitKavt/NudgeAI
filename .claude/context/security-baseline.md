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

## What triggers a security-reviewer pass

- Any change to Settings (API key entry/storage)
- Any change to the Classification module's request construction or
  response handling
- Any change to how `rawText` flows through the app
