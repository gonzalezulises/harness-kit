# PROGRESS.md — {{PROJECT_NAME}}

The durable memory of this repository. Every session reads this first and writes to it
last. If it disagrees with your recollection, this file wins.

## Current State

- **Last commit:** _(fill in: short hash + subject)_
- **Verification:** `{{VERIFY_CMD}}` — _not yet run_
- **Startup path:** `./init.sh`
- **Active feature:** _(none yet — see `feature_list.json`)_
- **Blocker:** _(none)_

## In Progress

_Nothing active. The next session should pick the highest-priority feature from
`feature_list.json` and set it to `active`._

## Next Steps

1. Replace the placeholder features in `feature_list.json` with real ones.
2. Fill in the verification command in `init.sh` if the detected one is wrong.
3. Activate the first feature and drive it to `passing`.

## Blockers

_(none)_

---

## Session Log

Newest first. One entry per session.

### {{DATE}} — harness bootstrap

- **Goal:** install the harness so later sessions start from a known state.
- **Completed:** scaffolded AGENTS.md, init.sh, feature_list.json, this file.
- **Verification run:** _pending_
- **Evidence:** _pending_
- **Commits:** _pending_
- **Known risks:** feature list is still placeholder content.
- **Next best action:** replace placeholder features with the real backlog.
