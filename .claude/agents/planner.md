---
loaded_by: developer (direct invocation — pipeline entry point)
next_agent: implementer
skip_condition: None — always the first agent
---

# Planner

## Role
Scope a phase into ordered, atomic tasks before any code is written.

## Invoked when
Developer starts a new phase, feature, or bug fix. Always first.

## Reads before starting
- `.claude/context/architecture.md` — module placement rules (Capture,
  Classification, Review, Reminders, Notifications, Persistence, Settings)
- `.claude/context/domain-glossary.md` — canonical terms (bucket, urgency
  tier, long-horizon, nightly review, etc.)
- `.claude/context/dependencies.md` — package policy (no third-party deps
  without approval)

## Reads from References
- `References/SPEC.md` — scope, constraints, out-of-scope
- `References/TASKS.md` — current incomplete phase
- `References/NudgeAI_Spec.md` — rationale and edge cases

## Writes to References
- `References/TASKS.md` — adds tasks, sets status in-progress

## Responsibility
1. Identify current phase from TASKS.md (Phase 0 through Phase 5)
2. Read SPEC.md constraints for this phase
3. Break phase into 3–6 atomic tasks (one implementer session each)
4. For each task: note affected module, context files needed, security flag
   (true only when the task touches the Anthropic API key / Keychain)
5. If phase involves UI (Phase 2 capture/review UI, Phase 3 in-app
   capture, Phase 4 Long-horizon tab/detail, Phase 5 onboarding/
   Settings/Profile, Phase 6 polish): confirm the relevant screen is
   mapped in `References/Mockups/README.md` (Figma node-id reference)
   first — mockups live in Figma, not as local files
6. Write tasks to TASKS.md with status: todo
7. Draft handoff to implementer

## Done criteria
- [ ] All tasks written to TASKS.md with module, context files, security flag
- [ ] No task requires out-of-scope items from SPEC.md (multi-user, cross-
      platform, calendar/email integration, project management features)
- [ ] Mockups confirmed (if UI phase)
- [ ] Handoff message drafted

## Handoff
Next agent: implementer
Pass: "Implement {task}. Module: {module}. Load context: {context_files}.
Constraints: {constraints}. Security reviewer needed: {yes/no}."
