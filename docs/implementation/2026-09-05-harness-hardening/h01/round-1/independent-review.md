# Spec Compliance

- ❌ **Issues found.** H01 does not yet satisfy blocked-state recovery authority, reliable attempt accounting, exact command framing, exact protected decision preservation, the distinction between a grep no-match and a failed tool, or unambiguous JSON object parsing. Six independently reproduced High/Important findings follow.
- ⚠️ The implementer's RED/GREEN suite results remain **reported evidence**, not independently read or rerun evidence. Full `make check` and the pre-commit gate remain controller responsibilities. The diff does not establish the required rollout inventory of multiline layers and duplicate IDs.
- ✅ Scope is confined to the four root verifiers and mirrors, regression integration, oracle, and Agent Note. H02 installer R11 and repair-only R12 are deliberately excluded by `tests/h01-hardening-regressions.py:43–89`; no finding here requests implementing H02.

# Strengths

- `scripts/verify-feature.sh:78–142,159–205` rejects duplicate feature IDs and malformed layers before creating the command channel, and checks activation/WIP before execution. `tests/h01-hardening-regressions.py:83–89` retains the three independent state probes.
- `scripts/verify-claims.sh:127–152,155–238` fails closed for missing explicit baseline files, resolves a Git tree before concluding the feature list was absent, validates baseline shape, and propagates parser failure. `scripts/verify-decisions.sh:33–67` similarly distinguishes an unreadable authority from proven ledger absence.
- `scripts/verify-claims.sh:266–284` executes each declared layer independently, with no command-text result cache. `tests/run-tests.sh:1069–1119` updates the observable execution-count assertions accordingly.
- `scripts/check-arch.sh:76–81,85–87` captures the command's actual exit and correctly rejects failing `exit0` rules. `scripts/verify-feature.sh:320–329` preserves the existing ledger on success and atomically replaces the JSON file.
- The complete added/context postimages in the frozen diff are identical for all four root/template pairs. `tests/run-tests.sh:219–240` adds an observable two-line command and a repair marker that must not execute.

# Issues

## Critical (Must Fix)

- None rated Critical; the following are High/Important and block H01 approval.

## Important (Should Fix)

### 1. High — Mutable state and maxima still reopen blocked work without authority

- **Location:** `scripts/verify-feature.sh:170–192` and its template mirror.
- **Defect:** The only historical stop checks compare the current ledger with current editable budget maxima. There is no durable blocked receipt or approved baseline/grant check. A feature blocked below either maximum is accepted after changing only `state` to `active`. An exhausted feature is accepted after increasing its maximum and editing `state`; the new maximum is never checked against approved authority.
- **Observed RED:** An initial blocked fixture with one spent round and maximum two exited 67. Changing only its state to active then ran `touch executed`, exited 0, and promoted it to passing. A second probe with two spent rounds and an edited maximum of three also ran the marker and exited 0.
- **Why it matters:** The new exhausted-ledger regression covers only unchanged maxima. It does not meet “una recuperación necesita un grant verificable, no editar state” or the binding approved-budget-authority requirement.
- **Fix/scope boundary:** H01 must either reject recovery when trusted historical authority is unavailable or explicitly narrow its claimed guarantee to unchanged exhausted ledgers/maxima. A recovery/approved-budget guarantee needs an externally trusted baseline or receipt; hashes beside mutable local state cannot supply that authority. H04 owns authenticated replay/state and H06 owns grants: this finding does not request building those systems in H01. It identifies that the H01 brief's stronger recovery guarantee is not established by the delivered preflight. Do not invent replacement maxima or an implicit grant during repair. Retain the observable marker regressions for both variants.

### 2. High — Accepted partial ledgers execute work without recording the failed attempt

- **Location:** `scripts/verify-feature.sh:121–142,234–258` and its template mirror.
- **Defect:** Preflight accepts an existing empty/partial ledger by defaulting missing `review_rounds` and `blockers`. The failure writer uses `setdefault("ledger", ...)`, which does not fill missing keys in an existing ledger, and immediately increments/indexes those keys.
- **Observed RED:** An active feature with valid bounded budgets, `ledger: {}`, and command `touch executed; false` ran the marker, then exited 1 with `KeyError: 'review_rounds'`. Its ledger remained `{}`. The budget receipt was not recorded, so another invocation can repeat the attempt without consuming the budget.
- **Why it matters:** Input that cannot be persisted safely passes preflight and produces effects. This directly violates complete input validation and persistent bounded attempts.
- **Fix:** Either reject incomplete explicit ledgers before effects, or normalize both keys consistently into the validated ledger before any execution and ensure the failure writer uses that validated contract. Handle `ledger: null` consistently as well; it is currently accepted in preflight but is not a mapping in the writer.

### 3. High — NUL-containing JSON commands execute different bytes and can earn PASS

- **Location:** `scripts/verify-feature.sh:106–107,199,218–223`; the equivalent command acceptance/read paths are `scripts/verify-claims.sh:70–71,117,269–271` and `scripts/check-arch.sh:49–50,63,69,76–78`, plus mirrors.
- **Defect:** A valid JSON string containing `\u0000` is accepted and written to the command file. Bash command substitution silently removes the NUL before `eval`. The command executed is therefore not the declared command. Feature command reads also omit the trailing-newline sentinel used by the other two scripts.
- **Observed RED:** The declared feature command `tou\u0000ch executed` ran as `touch executed`, created the marker, returned 0, and promoted the feature. Bash emitted `warning: command substitution: ignored null byte in input`.
- **Why it matters:** H01 promises unambiguous framing and commands preserved across the execution channel. Here malformed execution bytes become a different working command and a green receipt.
- **Fix:** Reject NUL (and other values that cannot be represented by the execution channel) during full preflight in all affected verifiers. Preserve trailing newlines consistently for accepted commands. Add an observable NUL regression; do not accept the warning as harmless.

### 4. High — Decision filename collisions silently discard protected entries

- **Location:** `scripts/verify-decisions.sh:88–96,118–126,134–145` and its template mirror.
- **Defect:** Decision headings are converted to slugs and duplicate slugs acquire numeric suffixes, but generated names are not globally collision-checked. A genuine heading `A-2` collides with the second `A` entry. The later write overwrites an earlier protected entry in both base and head before comparison.
- **Observed RED:** A baseline containing `## A-2` with `protected original`, followed by two `## A` entries, accepted a head that changed `protected original` to `silently rewritten`. The verifier exited 0 and reported only `2 decision(s) intact` although the ledger contains three entries.
- **Why it matters:** Byte comparison cannot protect an entry already discarded by lossy indexing. H01 therefore still accepts a protected historical decision rewrite.
- **Fix:** Use collision-free ordinal records preserving all entries, or reject ambiguous IDs explicitly; compare the actual protected entry sequence without overwriting records. Add this fixture before repair. The current text reads also normalize CRLF, and trailing whitespace/horizontal-rule removal is syntax-blind; an exact-byte implementation should avoid claiming byte identity after those transformations.

### 5. High — A grep substring converts a failed command into an architecture PASS

- **Location:** `scripts/check-arch.sh:89–98` and its template mirror.
- **Defect:** For `expect: empty`, exit 1 is accepted whenever the command text contains `grep` anywhere. A comment, filename, argument, or unrelated subcommand can satisfy this check even though the failing command is not a grep no-match.
- **Observed RED:** Rule command `false # grep` with `expect: empty` exited 1 internally, but the verifier returned 0 and printed `[OK] R` / `1 architecture rule(s) hold`.
- **Why it matters:** This is still a false green in the H01 requirement to distinguish a grep no-match from a tool failure. Testing only `exit0: false` does not cover the `empty` interpretation branch.
- **Fix:** Replace substring inference with an explicit, verifiable command/exit contract. If a compound legacy command cannot establish which command returned 1, reject it as ambiguous rather than treating it as a grep no-match. Preserve successful legitimate grep checks through narrowly defined handling, without adding a bypass flag.

### 6. High — Duplicate JSON keys hide conflicting state and commands before validation

- **Location:** `scripts/verify-feature.sh:65–69`, `scripts/verify-claims.sh:42–46,159–163`, `scripts/check-arch.sh:31–34`, plus mirrors.
- **Defect:** Default `json.load` silently retains the last occurrence of each object key. The subsequent whole-document checks never see a discarded `state`, `cmd`, or budget maximum, so conflicting declarations are silently normalized into an executable contract.
- **Observed RED:** One feature contained `"state":"blocked","state":"active"` and a layer contained `"cmd":"","cmd":"touch executed"`. `verify-feature` executed the marker, exited 0, and promoted the record. Its JSON rewrite erased the conflicting fields from the saved document.
- **Why it matters:** This is another H01 whole-input validation failure, not a request for future capability isolation. An ambiguous input is accepted before effects; consumers that interpret duplicates differently can disagree about state or authority.
- **Fix:** Use strict object parsing that rejects duplicate keys at every depth before schema validation or record emission, consistently in head and authority readers. Add one focused duplicate-key marker regression covering the executable contract.

## Minor (Nice to Have)

- `tests/run-tests.sh:57–61` discards all focal regression output. On failure the integrated suite reports only the group label, hiding the failing probe and traceback. Preserve a temporary log and print it when the group fails.

# Checks and Evidence

- Reviewed frozen diff target `0ca1ec165e699b155ed4498e6743cf8f4191874b` against base `9ee4eaaf6b19ded4b5e32349d77ba8fdaf6af79e`. The initial tool response truncated the diff; only missing script postimages were recovered from the same package. No changed working-tree file was separately read to expand the review, and no broad repository crawl or Git state commands were run.
- Ran only seven focused isolated probes addressing the six named unresolved doubts above, including the controller-requested duplicate-key check. They copy the reviewed scripts to temporary fixtures; repository, index, and HEAD remained read-only. No suite was rerun.
- Observed results, exact fixture inputs, and copied verifier snapshots are retained under `/workspace/scratch/adce1c53b293/h01-review-probes-o2onvm3u/`; result log: `/workspace/scratch/adce1c53b293/h01-review-probes-o2onvm3u/results.json`.
- The mirror check compares the frozen diff postimages for all four verifier pairs and returned true for every pair.
- Full installer behavior, repair-only re-earning, future capability isolation, deployment permissions, and historical claim changes were not evaluated beyond the H01 diff boundary.

# Assessment

**Task quality: Needs fixes.**

The change fixes several independently reported false-green paths, but six observable H01 contract violations remain, with the external-authority dependency for blocked recovery explicitly identified above. Both spec compliance and code quality are blocked until the in-scope cases have retained RED evidence, focused fixes, and independent review without High/Critical findings; the controller must resolve the H01 recovery guarantee against the later authority milestones.
