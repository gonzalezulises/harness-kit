# Clean State Checklist

Walk this before ending any session. A session is not complete until all five pass.
`make clean-check` automates it at the `full` harness level.

- [ ] **Build passes.** `make check` exits 0.
- [ ] **Startup works.** `./init.sh` runs clean from the current checkout.
- [ ] **State is current.** `PROGRESS.md` reflects reality: last commit, verification
      result, next step. No stale "in progress" entries from a finished session.
- [ ] **Feature list is honest.** No feature is marked `passing` without recorded
      evidence. Anything abandoned mid-way is back to `not_started` or marked `blocked`
      with the reason.
- [ ] **No debug artifacts.** No stray `console.log`, `print()`, `debugger`, commented-out
      blocks, `.orig`/`.rej` files, or temp scripts left in the tree.

## Why this exists

The expensive failure is not a bug — it is a session that ends in a state the next
session cannot read. An unfinished feature with clean state costs one session.
A "finished" feature with dirty state costs three.

If you cannot clear an item, do not silently skip it: write it into
`PROGRESS.md → Blockers` so the next session inherits the problem knowingly.
