# Oracles

One file per acceptance criterion that is critical enough that getting it wrong
ships harm. Not one per requirement — most requirements do not need this, and a
folder full of ceremonial oracles is worse than an empty one, because it teaches
everyone to skim.

`scripts/verify-oracles.sh` reads them. `make gates` runs it.

## What an oracle is for

It records what would prove the code **wrong**, written down before the code
exists. That ordering is the whole point: after you have written an
implementation, the tests you imagine are the ones it passes.

## The eight questions (V2 §9.3)

A criterion is `TEST_READY` only when all eight are answered. They are not
paperwork — each one has caught something real:

| # | Question | Field |
|---|---|---|
| 1 | What observable behaviour demonstrates compliance? | `observable` |
| 2 | What is the expected oracle? | `oracle` |
| 3 | Which positive, negative and boundary cases are required? | `cases` |
| 4 | Which actor, state and initial data are involved? | `context` |
| 5 | Which side effects must happen, and which must not? | `side_effects` |
| 6 | How would a false positive be detected? | `false_positive` |
| 7 | Who may change this oracle? | `owner` |
| 8 | What evidence does it produce? | `evidence` |

Question 7 is the one people skip, and it is the one that stops invented
thresholds: numbers nobody owns are numbers nobody agreed to.

## `falsification` — the field that is checked for truth

The other eight are checked for presence; prose can be written plausibly without
doing the work. This one is verified:

```yaml
falsification:
  defect: "Compare BCI groups by string equality again"
  proved_sha: "9f4bcca"
  output: "3 failed — 8D/D6 no longer matches 8D"
```

The gate checks that `proved_sha` is in this history, and that **no test named by
the oracle has been modified since it**. Edit the test after proving it can fail
and the proof no longer covers the test that exists: the criterion goes stale and
blocks.

Break it, watch it fail, record where. `git rev-parse --short HEAD` is the SHA.

## Statuses

| Status | Meaning |
|---|---|
| `DRAFT` | Being written. Critical criteria may not sit here while code relies on them |
| `DECISION_REQUIRED` | Blocked on a human decision. Say which, and who owns it |
| `TEST_READY` | All eight answered, tests exist, falsification proved |
| `DEFERRED` | Deliberately postponed. Needs a waiver with an expiry |
| `RETIRED` | No longer in force. Kept for its history |

## Honest limits

A SHA can be pasted without running anything. This gate makes the honest path the
easy one; it does not make dishonesty impossible, and a harness that claimed
otherwise would be the first thing lying to you.

What it does buy: the day someone edits a test to make a failure go away, the
proof goes stale and says so.
