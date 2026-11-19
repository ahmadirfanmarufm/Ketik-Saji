# Instruction to the developer agent — maintain project status in /docs

This carries forward the coordinator's explicit request for a regularly updated Markdown report inside the project so they can inspect the next push. The report is part of the implementation delivery, not merely a final chat message.

## Required repository destination

Update `/docs/PROJECT_STATUS.md` in the project. If that file exists, update it; do not create competing reports for the same current status. Use the repository's existing Markdown conventions and preserve useful history. This handoff document is an instruction; it is not a fabricated current-status report to copy unchanged into the repository.

Update it with every relevant implementation push during this phase, including partial pushes. State what actually works, what is incomplete, and what the developer needs the coordinator to validate. Mark untested behavior explicitly. A list of intended tasks alone is insufficient.

The source request was:

```text
read this new request.

also on another note, i want you to make a markdown file in the output zip telling the dev agent to report the current status of the project. since there may be errors and other things i need to validate. the report should be a markdown thats in /docs dir of the project. the report should be regularly updated, so that at the next push i can inspect it
```

## Include these fields

| Field | Required content |
| --- | --- |
| Updated | Real date/time with timezone, author/agent, branch, and identifiable code baseline. A report cannot embed its own future commit hash; use the tested parent/base or identify the tested working tree and include resulting commit in the delivery message. |
| Overall state | A short factual statement about playable flow, what the push changes, and material blockers. |
| Requirement status | Implemented / Partial / Missing / Inconsistent / Not verified, with each entry tied to a request or file in this handoff. Use implemented only for completed behavior; track validation separately. |
| Evidence | Source paths, actual checks run, exact automated outcomes, and manual visual/audio observations. Mark checks not run and why. |
| Known issues | Symptom, short reproduction, affected phase/screen, and practical impact. |
| Visual gaps | Missing menu background/logo/font/dish art, fallback appearance, unresolved bar-versus-ring treatment, and any layout deviation from the five references. |
| Audio status | Imported files/format, loop boundary, fade lifetime across scene teardown, click repeat policy, success/error triggers, Settings slider, and listening-test result. |
| Provisional choices | Any interpretation from documents 01/03/05, including HUD icon actions, prefix mirror, electricity badge semantics, equipment `+` binding, and Pause/Exit behavior. |
| Coordinator validation | Concrete steps the coordinator can follow in the pushed build, with expected visible/audible outcome. |
| Next work | Remaining ordered tasks and dependencies; do not mark absent art as completed because a placeholder is present. |

## Suggested compact structure

```markdown
# Project status

Updated: <actual date/time + timezone>
Branch / tested baseline: <actual branch and identifiable baseline>
Build / platform: <actual build or editor version and platform>

## Current playable state

<What was actually checked and what remains uncertain.>

## Requirement status

| Area / request | Status | Evidence and remaining work |
| --- | --- | --- |
| Thirteen recipes / M-01 | <status> | <actual icon/parts/unlock/price/description checks> |
| Ingredient unlocks / demand | <status> | <authoritative gating, +3/+2/+1 variety, frozen quota and weighting> |
| Main menu / UI-01 | <status> | <real evidence> |
| HUD and typing | <status> | <real evidence> |
| Edit Menu and ingredients | <status> | <real evidence> |
| Ingredient / equipment shops | <status> | <real evidence> |
| Three-tile counter slots C-01/C-02 | <status> | <real evidence: 3 items simultaneously per counter, independent placement/retrieval> |
| Dirty table marker | <status> | <real evidence> |
| Audio A-01 / fade A-02 | <status> | <real evidence> |
| Settings slider A-03 | <status> | <real evidence> |
| Results / win / lose R-01 | <status> | <real evidence: correct settled values, outcome, navigation, retry/reset> |
| Grape Soda / F-02 | <status> | <font imported/readable; no in-game attribution added> |
| One-panel help T-01 | <status> | <real evidence> |

## Validation performed

<Commands/checks and actual results; separate automated tests, real-window visual checks, and listening checks.>

## Known errors, missing assets, and deviations

<Reproduction and impact; identify provisional behavior.>

## Checks for the coordinator

<Specific actions and expected result in the pushed build.>

## Next work

<Remaining tasks in priority order.>
```

The developer's final delivery message should link this file in the resulting repository commit/push and identify any coordinator checks that could not be completed locally. Do not claim that this report was updated by the handoff preparer: this task has not modified the repository.
