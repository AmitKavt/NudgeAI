---
loaded_by: implementer
unlocks: correct logging practices that don't leak sensitive data
update_trigger: logging approach changes, or a new sensitive data type is introduced
owned_by: documenter
---

# Observability

## Logging

- Use `os.Logger` (unified logging), not `print()`/`debugPrint()`.
- Log at the module boundary level: capture received, classification
  started/completed/failed, notification scheduled, review surfaced —
  enough to debug the pipeline without reconstructing app state.
- Log levels: `.info` for normal flow events, `.error` for classification
  failures / API errors, `.debug` for anything only useful during active
  development (strip or gate behind a debug build flag before Phase 5).

## What must never be logged

- The Anthropic API key, in any form or fragment.
- Full `rawText` content in production logs — if content is needed for
  debugging, log length/hash only, not the reminder text itself, since
  this is personal data the user chose to keep private to the app.
- Raw Claude API response bodies in production (log parse success/failure
  and the structured fields only).

## Crash reporting

- No third-party crash reporting SDK in v1 (see dependencies.md). Rely on
  Xcode Organizer crash logs during development and TestFlight if used.
