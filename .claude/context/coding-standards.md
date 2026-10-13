---
loaded_by: implementer
unlocks: consistent, idiomatic Swift/SwiftUI code matching project conventions
update_trigger: a new pattern is adopted project-wide, or a style decision is made
owned_by: documenter
---

# Coding Standards (Swift / SwiftUI)

## Naming

- Types: UpperCamelCase (`ReminderItem`, `ClassificationClient`)
- Properties/functions: lowerCamelCase (`rawText`, `scheduleNotification()`)
- Enums use the domain terms from `domain-glossary.md` exactly
  (`bucket: quickTask | scheduledTask | longHorizon`, not abbreviations)
- Protocols describing a capability end in the capability, not `-able`
  unless idiomatic (e.g. `ReminderRepository`, not `Repoable`)

## Forbidden patterns

- No force unwraps (`!`) outside of IBOutlet-style guaranteed-non-nil
  framework callbacks — use `guard let` / `if let` / nil-coalescing.
- No `print()` / `debugPrint()` in shipped code — use the observability
  logging pattern instead.
- No `TODO` / `FIXME` left in code handed to code-reviewer — either finish
  it or file it as a TASKS.md item.
- No singletons for anything holding user data — pass dependencies
  explicitly (repositories, clients) via initializers or environment.

## Required patterns

- Pure business logic (classification JSON parsing, notification
  scheduling math, reschedule calculations) lives in plain Swift types
  with zero `import SwiftUI` / `import SwiftData` — these must be
  unit-testable in isolation.
- All async work (Classification API calls, Speech transcription) uses
  Swift concurrency (`async`/`await`), not completion handlers.
- SwiftData models and UI views are kept in separate files; a View never
  directly constructs a `ModelContext` query inline — it goes through a
  repository.
- Dates are always handled as `Date` (UTC-backed); formatting/display
  localization happens only at the UI layer.

## Concurrency model

- Classification calls run on a background task triggered immediately
  after the local Persistence write; UI must never await this call.
- Nightly review and long-horizon notification scheduling run via
  background tasks (e.g. `BGTaskScheduler`), not foreground-only timers.
