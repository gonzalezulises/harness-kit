# Finding Verdicts

1. **Positive blocker history with zero review rounds bypasses recovery — ADDRESSED.** `scripts/verify-feature.sh:141–155` now sums validated blocker counts and rejects a ledger whose total differs from `review_rounds`, before any layer record is executed. Positive blocker history can no longer coexist with zero rounds and be treated as a first attempt. The same invariant is applied to claims head and authority at `scripts/verify-claims.sh:102–114,235–246`. The final diff adds separate observable marker cases for feature, claims head, and claims authority at `tests/h01-hardening-regressions.py:135,144,158`. The unchanged conservative recovery rule handles valid positive-round history; no new authority mechanism or budget maximum is introduced.

2. **Invalid regex filters can execute effects or hide behind no-match — ADDRESSED.** `scripts/check-arch.sh:90–91` compiles each filter during the existing whole-document parser and maps invalid syntax to configuration exit 2. Execution starts only after that parser succeeds, so an invalid later rule prevents earlier effects, and a matcher cannot bypass validation through its no-match return. The final diff separates the earlier-rule marker and no-match marker cases at `tests/h01-hardening-regressions.py:251,270`.

3. **Appended separator/heading content can extend the protected final line — NOT ADDRESSED.** `scripts/verify-decisions.sh:106–111` correctly searches for the heading in combined head bytes, closing the original direct `protected original## B` variant. However, lines 111–115 still validate separator lines relative to the suffix without considering the baseline's final line. The controller-requested exact variant, baseline `## A\nprotected original` plus suffix `---\n## B\nnew decision\n`, is accepted with exit 0 and `1 decision(s) intact, 1 added.` Its dashes extend the old decision to `protected original---`; they are not a document horizontal rule. Require a real line break before any allowed separator content as well as the new heading when the nonempty baseline ends without a newline. Add this exact negative fixture alongside the valid separated append at `tests/h01-hardening-regressions.py:287–304`. **High/Important remains open.**

# New Breakage in the Fix Diff

- No separate new issue found. The append-separator variant is the incomplete repair of finding 3, not a new scope item. The four root/template fix diffs are identical.

# Final Evidence — Prior Caveat Resolved

- Read the atomic final capture `/workspace/scratch/adce1c53b293/h01-evidence/review-round2/freeze-bedd36caa4274691a841ff3e615d211d.json`: **31 tests, OK, exit 0**, with all separately named feature/head/authority and preflight/no-match methods. Its test SHA-256 is `3754ec927d52c3d4e051e5e8a5b63a6c76dae5fc357173d85ed3c12b487d8f47`, matching the final test file previously checked. The final-suite mismatch is resolved.
- Read the complete `/workspace/scratch/adce1c53b293/h01-evidence/review-round2/red31-3754ec92.stderr.log` and `.exit`: **31 tests, six assertion failures, zero errors, exit 1**. The six independently exposed paths are feature/head/authority inconsistent ledgers, whole-document and no-match regex validation, and the direct-concatenation decision boundary. `expanded-frozen-tree-red.sha256` binds the final test hash and the four retained pre-fix script snapshots extracted from frozen tree `f1fa81c...`. This complete RED log resolves the earlier truncated-log caveat.
- The amended implementer report distinguishes the initial 28-test chronology from the final split 31-test suite. Per the controller, the earlier report was read while test splitting and evidence finalization were still in progress, before the explicit freeze; no commit or published completion depended on that interim state. Final evidence is now inspected directly. No additional code probes or test reruns were performed for this report amendment.

# Out-of-Scope Observations

- None. H04 external-history authority, H06 grants, H02 installer/re-earning behavior, historical F09 certification, and the full pre-commit check remain outside this scoped re-review.

# Checks

- Reviewed the appended round-2 report and fix package from frozen index `f1fa81c07241f1759203d2890e43c84520cc3484` to `c54d3abddcca748b74ecddd30084330201fa936a`. Initial output truncated part of a duplicated template hunk; all four template fix hunks were then mechanically compared with their already-read root hunks and matched.
- Read stored final focal GREEN capture, complete RED31 output/exit, final quick-gate output/exit, final syntax/mirror log, and artifact hashes. Final quick gates show 8 pass / 0 blocking, exit 0, with empty stderr; final syntax/mirror log shows 9/9 and 4/4. The focal-test hash check and final atomic capture resolve the prior evidence mismatch.
- Ran one isolated probe for the controller-requested append-separator variant; it reproduced the undesired success. Exact base/head inputs, a copied verifier snapshot, output, and exit are retained at `/workspace/scratch/adce1c53b293/h01-rereview2-append-nok05r7l/`; result file: `/workspace/scratch/adce1c53b293/h01-rereview2-append-nok05r7l/results.json`. No suite was rerun. Repository, index, and HEAD remained read-only.

# Verdict

**Spec compliance: Issues found — append-boundary finding 3 remains open.**

**Code quality: Needs fixes.**

**Fix round: Findings remain open.** Findings 1 and 2 are addressed. Finding 3 remains High/Important for a separator that extends the protected final line. Final split-test evidence is verified; the full `make check` remains a controller verification gate before commit. No Critical finding.
