# Agent Notes

An **Agent Note** records a decision that affects this repository — the *why*
and *what was given up*, the parts code and docs cannot carry. The path encodes
everything, so the tree itself is the inventory (deliberately: no `INDEX.md`,
because an index rots while a `find` does not):

```
.agents/notes/{lifecycle}/{class}/yyyy-mm-dd-topic-title.md
```

`scripts/verify-agent-notes.sh` (part of `make gates`) enforces the layout.

## Lifecycle (top folder — a note MOVES as its status changes)

| Folder | Meaning |
|---|---|
| `proposed/` | Reviewed before implementation; not built yet. |
| `implemented/` | Shipped. Kept current with facts (paths, names) — never with a different decision. |
| `rejected/` | Considered and declined. Keep only while the rationale prevents a tempting mistake. |

## Class (nested folder — the kind of decision)

`feature` · `bug-fix` · `simplification` · `architecture` (structure of the
shipped source) · `process` (tooling and workflow around the code) · `testing`.

## When to write one

**Every non-trivial change adds or updates an Agent Note in the same PR.**
Non-trivial = it alters behavior, a cross-file contract, process, testing
strategy, or an on-disk/wire format — anything a maintainer may reasonably
revisit. Updating the note that already owns the decision satisfies the rule.

A note is never edited into a *different* decision: supersede it with a new one
and cross-link both. The date in the filename is when the topic was first
proposed; it never changes.

## Format

First line: `# Title`. Then, in prose: the decision, the alternatives rejected
and why, what was given up, and the condition under which it should be
revisited. Current-state prose — not a reasoning transcript. Link related notes
with relative markdown links so moves stay mechanically checkable.

## Relation to `DECISIONS.md`

`DECISIONS.md` stays the fast append-only ledger (guarded by
`verify-decisions.sh` in CI): one short entry per decision. A decision with real
alternatives and consequences gets a full Agent Note here, and its ledger entry
links to it. One fact, one home: the ledger entry points, the note owns.
