# The auditor's counters returned two lines, so a correct repo scored 83/84

**Decided:** `harness-audit.sh` counts through one `count_matches` helper that
always returns a single integer. Five call sites moved to it — the VCR
activated/passing pair and the three budget counters.

**Why:** `grep -c` prints `0` **and** exits 1 when nothing matches, so the idiom
`$(grep -c … || echo 0)` appended a second zero. The variable held `"0\n0"`,
every arithmetic comparison using it blew up, and the check reported an empty
result — read downstream as a failure.

The damage was not the wrong digit. `enf.stopcond` was unpassable for any repo
without a `budget_defaults` block, no matter how complete its budgets were, and
its repair text told the user to add `stop_condition` to blocks that already had
one. An auditor that sends you to fix something already correct spends trust it
cannot rebuild — and this one scores every repository the kit governs. This repo
had been at a true 84/84 while reporting 83.

The same idiom sat in the VCR counters, where a repo with no `active` features —
the normal state once everything passes — hit the identical break.

**Given up:** the shell-only JSON heuristics stay heuristics; `count_matches`
fixes how they count, not that counting braces is a poor substitute for parsing.
Left alone deliberately: the kit runs where only bash exists, and that
constraint is why the auditor travels at all. Regression test pins the shape
that used to break — complete budgets, no `budget_defaults` — and it fails
against the previous counters.
