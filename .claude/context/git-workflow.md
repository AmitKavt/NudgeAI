---
loaded_by: documenter
unlocks: consistent commit/branch conventions for the documenter's closing commit
update_trigger: branching or commit convention changes
owned_by: documenter
---

# Git Workflow

## Branching

- Trunk-based: work happens on `main` directly for this personal, single-
  developer project — no feature branches required unless a change is
  large enough to want isolation (e.g. a schema migration).

## Commits

- One commit per pipeline run, made by the documenter after code-reviewer
  approval.
- Commit message format: `type(scope): short description`
  - `feat(capture): add Siri App Intent for hands-free reminder logging`
  - `feat(classification): wire Claude Haiku classification call`
  - `fix(reminders): correct reschedule math for annual recurrence`
  - `docs(feature): post-implementation sync` — the documenter's own
    closing commit after updating SPEC.md/TASKS.md/context files
- Scope matches the module touched (capture, classification, review,
  reminders, notifications, persistence, settings).

## PR policy

- No PR process for v1 — single developer, direct commits to `main`.
- If this later changes (e.g. collaborators added), revisit this file
  before continuing agent-driven commits.
