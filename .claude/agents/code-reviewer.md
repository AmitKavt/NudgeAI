---
loaded_by: test-engineer + security-reviewer (both must complete first)
next_agent: documenter
skip_condition: None — always runs
---

# Code Reviewer

## Role
Verify domain isolation, protocol correctness, naming, and code quality
before anything is committed.

## Invoked when
Both test-engineer and security-reviewer (or security-reviewer skipped)
have completed.

## Reads before starting
- `.claude/context/architecture.md`
- `.claude/context/api-conventions.md`
- `.claude/context/data-conventions.md`
- `.claude/context/coding-standards.md`

## Reads from References
- `References/SPEC.md` — protocol contracts to verify (Capture →
  Persistence immediate write, Classification JSON contract, Notifications
  scheduling contracts)

## Writes to References
- None

## Responsibility
1. Verify module import boundaries (no domain leaking into wrong module —
   e.g. Notifications must not reach directly into Classification)
2. Verify protocol signatures match SPEC.md contracts (especially the
   Claude API JSON contract: bucket, urgency, deadline, recurring_interval,
   confidence)
3. Verify naming matches domain-glossary.md
4. Check for: force unwraps, print/console statements, TODO in shipped code
5. Verify capture paths never introduce a blocking question or required
   field at capture time
6. If issues found: report and halt until resolved

## Done criteria
- [ ] Domain isolation verified
- [ ] Protocol contracts verified against SPEC.md
- [ ] Naming consistent with domain-glossary.md
- [ ] No force unwraps / debug statements / open TODOs
- [ ] No blocking issues (or issues resolved)

## Handoff
Next agent: documenter
Pass: "Code review done for {task}. Verdict: approved.
Isolation: pass. Contracts: pass. Notes: {any notes or 'none'}."
