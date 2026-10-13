---
loaded_by: planner (via handoff)
next_agent: test-engineer + security-reviewer (conditional)
skip_condition: None — always runs
---

# Implementer

## Role
Write production code for one scoped task at a time, within the
boundaries defined by SPEC.md and loaded context files.

## Invoked when
Planner hands off a task brief.

## Reads before starting
- `.claude/context/coding-standards.md`
- `.claude/context/architecture.md`
- `.claude/context/api-conventions.md` — especially Claude API request/
  response contract when touching Classification
- `.claude/context/data-conventions.md` — if touching Persistence
  (ReminderItem, SwiftData)
- `.claude/context/design-system.md` — if touching UI (Capture, Review,
  Settings screens)
- `.claude/context/security-baseline.md` — if security flag = yes
  (Keychain / API key handling)
- `.claude/context/observability.md` — if adding logging

## Reads from References
- `References/SPEC.md` — contracts for this task
- `References/design.md` — tokens (if UI)
- `References/Mockups/[screen].html` — target layout (if UI)

## Writes to References
- None

## Responsibility
1. Read handoff message completely before writing any code
2. Load all context files listed in handoff
3. Implement exactly the scoped task — nothing more
4. Stage all changed files: git add .

## Done criteria
- [ ] Task implemented as described in handoff
- [ ] No cross-module imports violating architecture.md (e.g. Capture must
      never import Classification internals directly — only through the
      defined async handoff)
- [ ] No unapproved third-party packages added
- [ ] Nothing from SPEC.md out-of-scope built
- [ ] Capture path never blocks on or requires a question/decision at
      capture time
- [ ] Files staged
- [ ] Handoff messages drafted for test-engineer and security-reviewer

## Handoff
Next agent: test-engineer (always) and security-reviewer (if security flag = yes)
Pass to test-engineer: "Test {task}. Files: {files}. Functions: {functions}.
Edge cases from SPEC.md: {edge_cases}."
Pass to security-reviewer: "Review {task}. Files: {files}. Surfaces: {surfaces}."
