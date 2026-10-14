---
loaded_by: planner, implementer
unlocks: knowing what packages are pre-approved vs. require explicit sign-off
update_trigger: a new dependency is approved or banned
owned_by: documenter
---

# Dependencies

## Policy

No third-party dependencies without explicit approval from the developer.
This app is designed to run entirely on Apple frameworks plus one optional network
dependency (the user's chosen LLM platform, Anthropic or DeepSeek, over
URLSession), per CLAUDE.md's non-
negotiable rules.

## Approved (all first-party, no install step needed)

- SwiftUI
- SwiftData
- App Intents
- Speech (on-device transcription)
- UserNotifications (UNUserNotificationCenter)
- Security framework (Keychain access)
- AuthenticationServices (Sign in with Apple, local identity only)
- URLSession (Foundation) — the only network call, to the chosen LLM platform's API (optional)
- XCTest / Swift Testing — for test-engineer's unit tests

## Banned without explicit approval

- Any third-party networking library (Alamofire, etc.) — URLSession is
  sufficient for a single API endpoint.
- Any LLM provider SDK (Anthropic, DeepSeek, OpenAI-compatible) — use
  the URLSession adapters.
- Any third-party Keychain wrapper — use Security framework directly to
  avoid an extra trust boundary around the API key.
- Any analytics/crash-reporting SDK — not needed for a personal single-
  user app in v1, and would add a data flow the security baseline doesn't
  account for.

## Approval process

- If a task seems to need a package not listed above, the implementer
  stops and raises it to the developer rather than adding it silently.
  Update this file once a decision is made.
