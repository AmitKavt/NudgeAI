# Mockups

Mockups for Nudge AI live in Figma, not as local HTML/image files:
https://www.figma.com/design/oB82tlQm7eyDgsMdIuHKjx/Nudge-AI-%E2%80%94-iOS-Designs

When the planner or implementer needs a screen's layout, open the
relevant node directly rather than expecting a file in this folder.

## Screen → node-id map (page "Nudge AI — Screens", node 4:4 subtree)

| # | Screen | Node id |
|---|---|---|
| 1 | Welcome | 6:2 |
| 2 | Connect Claude | 6:25 |
| 3 | Siri phrase | 6:61 |
| 4 | Permissions | 6:109 |
| 5 | Today | 7:12 |
| 6 | Capture (Claude asks) | 7:93 |
| 7 | Nightly review | 7:149 |
| 8 | Today (Claude unreachable) | 7:200 |
| 9 | Long-horizon | 8:74 |
| 10 | Reminder detail | 8:148 |
| 11 | Escalating notifications | 8:206 |
| 12 | You (Profile) | 8:248 |
| 13 | Settings | 9:131 |
| 14 | Review and nudge timing | 9:211 |
| 15 | Claude and privacy | 9:281 |
| 16 | Capture settings | 9:334 |

An earlier, 3-screen pass of the same flows (Siri capture, Home, Capture
chat) also exists at node 0:1 in the same file — superseded by the 16
screens above; kept for history only.

## Keeping this current

If the Figma file changes (new screens, renamed frames, a redesign of an
existing flow), re-run `get_metadata` on node 4:4, update the table
above, and re-sync `NudgeAI_Spec.md`/`SPEC.md`/`design.md` via the
documenter rather than letting this map drift.
